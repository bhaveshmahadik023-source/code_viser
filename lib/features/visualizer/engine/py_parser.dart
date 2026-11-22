import 'py_ast.dart';
import 'py_error.dart';
import 'py_lexer.dart';

/// Words that cannot be used as variable names.
const _reserved = {
  'if', 'elif', 'else', 'while', 'for', 'in', 'def', 'return', 'break', //
  'continue', 'pass', 'and', 'or', 'not', 'is', 'True', 'False', 'None',
  'lambda', 'import', 'from', 'class', 'try', 'except', 'finally', 'with',
  'global', 'nonlocal', 'del', 'assert', 'yield', 'raise', 'as', 'async',
  'await',
};

const _augOps = {
  '+=', '-=', '*=', '/=', '//=', '%=', '**=', '|=', '&=', '^=', '<<=', '>>=',
};

/// Reads tokens and builds the tree of statements.
class Parser {
  Parser(this.src, {int firstLine = 1})
      : tokens = tokenize(src, firstLine: firstLine);

  final String src;
  final List<Token> tokens;
  int _p = 0;

  // ------------------------------ helpers ------------------------------

  Token get _cur => tokens[_p];

  Token _peek(int offset) {
    final k = _p + offset;
    return tokens[k < tokens.length ? k : tokens.length - 1];
  }

  bool _isOp(String t) => _cur.type == TokType.op && _cur.text == t;
  bool _isKw(String t) => _cur.type == TokType.name && _cur.text == t;

  Token _advance() => tokens[_p++];

  PyError _err(String message) => PyError(_cur.line, message);

  Token _expectOp(String t) {
    if (!_isOp(t)) {
      final found = _cur.type == TokType.newline
          ? 'end of line'
          : (_cur.type == TokType.eof ? 'end of code' : "'${_cur.text}'");
      throw _err("Expected '$t' but found $found");
    }
    return _advance();
  }

  String _identifier(String what) {
    if (_cur.type != TokType.name || _reserved.contains(_cur.text)) {
      throw _err('Expected $what');
    }
    return _advance().text;
  }

  /// Source text from [start] to the last consumed token.
  String _srcFrom(Token start) => src.substring(start.start, tokens[_p - 1].end);

  void _endSimple() {
    if (_isOp(';')) {
      _advance();
      if (_cur.type == TokType.newline) _advance();
      return;
    }
    if (_cur.type == TokType.newline) {
      _advance();
    } else if (_cur.type != TokType.eof) {
      throw _err("Unexpected '${_cur.text}'");
    }
  }

  // ----------------------------- statements ----------------------------

  List<Stmt> parseProgram() {
    final out = <Stmt>[];
    while (_cur.type != TokType.eof) {
      if (_cur.type == TokType.newline) {
        _advance();
        continue;
      }
      if (_cur.type == TokType.indent) {
        throw _err('Unexpected indentation');
      }
      out.add(_statement());
    }
    return out;
  }

  /// Used for the expressions inside an f-string.
  Expr parseExpressionOnly() {
    final e = _exprList();
    if (_cur.type == TokType.newline) _advance();
    if (_cur.type != TokType.eof) {
      throw _err("Unexpected '${_cur.text}' in the expression");
    }
    return e;
  }

  Stmt _statement() {
    final t = _cur;
    if (t.type == TokType.name) {
      switch (t.text) {
        case 'if':
          return _ifStmt();
        case 'while':
          return _whileStmt();
        case 'for':
          return _forStmt();
        case 'def':
          return _funcDef(const <String>[]);
        case 'class':
          return _classDef();
        case 'try':
          return _tryStmt();
        case 'return':
          _advance();
          Expr? value;
          if (_cur.type != TokType.newline &&
              _cur.type != TokType.eof &&
              !_isOp(';')) {
            value = _exprList();
          }
          _endSimple();
          return ReturnStmt(t.line, value);
        case 'break':
          _advance();
          _endSimple();
          return BreakStmt(t.line);
        case 'continue':
          _advance();
          _endSimple();
          return ContinueStmt(t.line);
        case 'pass':
          _advance();
          _endSimple();
          return PassStmt(t.line);
        case 'import':
          return _importStmt();
        case 'from':
          return _fromImport();
        case 'global':
          return _globalStmt();
        case 'del':
          return _delStmt();
        case 'assert':
          return _assertStmt();
        case 'raise':
          return _raiseStmt();
        case 'elif':
        case 'else':
        case 'except':
        case 'finally':
          throw PyError(t.line, "'${t.text}' without a matching 'if' or 'try'");
        case 'with':
          throw PyError(t.line,
              "'with' blocks (for example open files) are not supported yet");
        case 'nonlocal':
        case 'yield':
        case 'async':
        case 'await':
          throw PyError(t.line, "'${t.text}' is not supported yet");
      }
    }
    if (_isOp('@')) return _decorated();
    return _simpleStmt();
  }

  /// Reads ":" and then a block.
  List<Stmt> _suite() {
    _expectOp(':');
    return _block();
  }

  List<Stmt> _block() {
    if (_cur.type == TokType.newline) {
      _advance();
      if (_cur.type != TokType.indent) {
        throw _err('Expected an indented block');
      }
      _advance();
      final out = <Stmt>[];
      while (_cur.type != TokType.dedent && _cur.type != TokType.eof) {
        if (_cur.type == TokType.newline) {
          _advance();
          continue;
        }
        out.add(_statement());
      }
      if (_cur.type == TokType.dedent) _advance();
      return out;
    }
    // One-line block, for example: if x: y = 1
    return [_simpleStmt()];
  }

  Stmt _ifStmt() {
    final kw = _advance(); // "if" or "elif"
    final test = _expr();
    final body = _suite();
    var orelse = <Stmt>[];
    int? elseLine;
    if (_isKw('elif')) {
      orelse = [_ifStmt()];
    } else if (_isKw('else')) {
      elseLine = _cur.line;
      _advance();
      orelse = _suite();
    }
    return IfStmt(kw.line, test, body, orelse, elseLine);
  }

  Stmt _whileStmt() {
    final kw = _advance();
    final test = _expr();
    final body = _suite();
    var orelse = <Stmt>[];
    int? elseLine;
    if (_isKw('else')) {
      elseLine = _cur.line;
      _advance();
      orelse = _suite();
    }
    return WhileStmt(kw.line, test, body, orelse, elseLine);
  }

  Stmt _forStmt() {
    final kw = _advance();
    final start = _cur;
    final targets = <Expr>[_postfix()];
    while (_isOp(',')) {
      _advance();
      targets.add(_postfix());
    }
    final Expr target = targets.length == 1
        ? targets.first
        : TupleLit(start.line, _srcFrom(start), targets);
    _checkTarget(target);
    if (!_isKw('in')) throw _err("Expected 'in' in the for loop");
    _advance();
    final iter = _exprList();
    final body = _suite();
    var orelse = <Stmt>[];
    int? elseLine;
    if (_isKw('else')) {
      elseLine = _cur.line;
      _advance();
      orelse = _suite();
    }
    return ForStmt(kw.line, target, iter, body, orelse, elseLine);
  }

  Stmt _decorated() {
    final decorators = <String>[];
    while (_isOp('@')) {
      _advance();
      final start = _cur;
      final e = _postfix();
      decorators.add(_srcFrom(start));
      if (e is Call) {
        throw PyError(start.line, 'Decorators with arguments are not supported yet');
      }
      if (_cur.type == TokType.newline) _advance();
    }
    if (!_isKw('def')) {
      throw _err("A decorator must be followed by 'def'");
    }
    return _funcDef(decorators);
  }

  Stmt _funcDef(List<String> decorators) {
    final kw = _advance();
    final name = _identifier('a function name');
    _expectOp('(');
    final params = <String>[];
    final defaults = <Expr?>[];
    while (!_isOp(')')) {
      if (_isOp('*') || _isOp('**')) {
        throw _err('*args and **kwargs are not supported yet');
      }
      params.add(_identifier('a parameter name'));
      if (_isOp(':')) {
        // Type hint such as x: int. It is read and ignored.
        _advance();
        _expr();
      }
      if (_isOp('=')) {
        _advance();
        defaults.add(_expr());
      } else {
        defaults.add(null);
      }
      if (_isOp(',')) {
        _advance();
      } else {
        break;
      }
    }
    _expectOp(')');
    if (_isOp('->')) {
      _advance();
      _expr(); // return type hint is ignored
    }
    final body = _suite();
    return FuncDef(kw.line, name, params, defaults, body, decorators);
  }

  Stmt _classDef() {
    final kw = _advance();
    final name = _identifier('a class name');
    final bases = <Expr>[];
    if (_isOp('(')) {
      _advance();
      while (!_isOp(')')) {
        bases.add(_expr());
        if (_isOp(',')) {
          _advance();
        } else {
          break;
        }
      }
      _expectOp(')');
    }
    final body = _suite();
    return ClassDef(kw.line, name, bases, body);
  }

  Stmt _tryStmt() {
    final kw = _advance();
    final body = _suite();
    final handlers = <ExceptHandler>[];
    var orelse = <Stmt>[];
    var finalbody = <Stmt>[];
    int? elseLine;
    int? finallyLine;
    while (_isKw('except')) {
      final h = _advance();
      Expr? type;
      String? name;
      if (!_isOp(':')) {
        type = _expr();
        if (_isKw('as')) {
          _advance();
          name = _identifier('a name after as');
        }
      }
      handlers.add(ExceptHandler(h.line, type, name, _suite()));
    }
    if (handlers.isNotEmpty && _isKw('else')) {
      elseLine = _cur.line;
      _advance();
      orelse = _suite();
    }
    if (_isKw('finally')) {
      finallyLine = _cur.line;
      _advance();
      finalbody = _suite();
    }
    if (handlers.isEmpty && finalbody.isEmpty) {
      throw PyError(kw.line, "'try' needs an 'except' or 'finally' part");
    }
    return TryStmt(kw.line, body, handlers, orelse, finalbody, elseLine, finallyLine);
  }

  String _dottedName() {
    final parts = <String>[_identifier('a module name')];
    while (_isOp('.')) {
      _advance();
      parts.add(_identifier('a name after the dot'));
    }
    return parts.join('.');
  }

  Stmt _importStmt() {
    final kw = _advance();
    final items = <List<String>>[];
    while (true) {
      final module = _dottedName();
      var alias = '';
      if (_isKw('as')) {
        _advance();
        alias = _identifier('a name after as');
      }
      items.add([module, alias]);
      if (_isOp(',')) {
        _advance();
      } else {
        break;
      }
    }
    _endSimple();
    return ImportStmt(kw.line, items);
  }

  Stmt _fromImport() {
    final kw = _advance();
    final module = _dottedName();
    if (!_isKw('import')) throw _err("Expected 'import'");
    _advance();
    if (_isOp('*')) {
      throw _err("'from ... import *' is not supported yet");
    }
    final items = <List<String>>[];
    final paren = _isOp('(');
    if (paren) _advance();
    while (true) {
      final name = _identifier('a name to import');
      var alias = '';
      if (_isKw('as')) {
        _advance();
        alias = _identifier('a name after as');
      }
      items.add([name, alias]);
      if (_isOp(',')) {
        _advance();
        if (paren && _isOp(')')) break;
      } else {
        break;
      }
    }
    if (paren) _expectOp(')');
    _endSimple();
    return FromImportStmt(kw.line, module, items);
  }

  Stmt _globalStmt() {
    final kw = _advance();
    final names = <String>[_identifier('a variable name')];
    while (_isOp(',')) {
      _advance();
      names.add(_identifier('a variable name'));
    }
    _endSimple();
    return GlobalStmt(kw.line, names);
  }

  Stmt _delStmt() {
    final kw = _advance();
    final targets = <Expr>[_postfix()];
    while (_isOp(',')) {
      _advance();
      targets.add(_postfix());
    }
    _endSimple();
    return DelStmt(kw.line, targets);
  }

  Stmt _assertStmt() {
    final kw = _advance();
    final test = _expr();
    Expr? msg;
    if (_isOp(',')) {
      _advance();
      msg = _expr();
    }
    _endSimple();
    return AssertStmt(kw.line, test, msg);
  }

  Stmt _raiseStmt() {
    final kw = _advance();
    Expr? exc;
    if (_cur.type != TokType.newline &&
        _cur.type != TokType.eof &&
        !_isOp(';')) {
      exc = _expr();
    }
    _endSimple();
    return RaiseStmt(kw.line, exc);
  }

  Stmt _simpleStmt() {
    final startTok = _cur;
    final first = _exprList();
    Stmt s;
    if (_isOp(':') && first is Name) {
      // Variable type hint such as x: int = 5. The hint is ignored.
      _advance();
      _expr();
      if (_isOp('=')) {
        _advance();
        s = Assign(startTok.line, first, _exprList());
      } else {
        s = PassStmt(startTok.line);
      }
    } else if (_isOp('=')) {
      final targets = <Expr>[first];
      Expr value = first;
      while (_isOp('=')) {
        _advance();
        value = _exprList();
        if (_isOp('=')) targets.add(value);
      }
      for (final t in targets) {
        _checkTarget(t);
      }
      s = Assign(startTok.line, targets.first, value,
          targets.sublist(1));
    } else if (_cur.type == TokType.op && _augOps.contains(_cur.text)) {
      final raw = _advance().text;
      final op = raw.substring(0, raw.length - 1);
      final value = _expr();
      if (first is! Name && first is! Subscript && first is! Attribute) {
        throw PyError(startTok.line, 'Cannot use $raw on this expression');
      }
      s = AugAssign(startTok.line, first, op, value);
    } else {
      s = ExprStmt(startTok.line, first);
    }
    _endSimple();
    return s;
  }

  void _checkTarget(Expr t) {
    if (t is Name || t is Subscript || t is Attribute) return;
    if (t is TupleLit) {
      for (final item in t.items) {
        _checkTarget(item);
      }
      return;
    }
    throw PyError(t.line, 'Cannot assign to this expression');
  }

  // ---------------------------- expressions ----------------------------

  bool _atExprEnd() {
    if (_cur.type == TokType.newline || _cur.type == TokType.eof) return true;
    return _cur.type == TokType.op &&
        (_cur.text == '=' ||
            _cur.text == ')' ||
            _cur.text == ']' ||
            _cur.text == '}' ||
            _cur.text == ':' ||
            _cur.text == ';');
  }

  /// One expression or a comma separated tuple.
  Expr _exprList() {
    final start = _cur;
    final first = _expr();
    if (!_isOp(',')) return first;
    final items = <Expr>[first];
    while (_isOp(',')) {
      _advance();
      if (_atExprEnd()) break;
      items.add(_expr());
    }
    return TupleLit(start.line, _srcFrom(start), items);
  }

  Expr _expr() {
    final start = _cur;
    if (_isKw('lambda')) return _lambda();
    final body = _or();
    if (_isKw('if')) {
      _advance();
      final test = _or();
      if (!_isKw('else')) {
        throw _err("Expected 'else' in the conditional expression");
      }
      _advance();
      final orelse = _expr();
      return IfExp(start.line, _srcFrom(start), test, body, orelse);
    }
    return body;
  }

  Expr _lambda() {
    final start = _advance(); // lambda
    final params = <String>[];
    final defaults = <Expr?>[];
    while (!_isOp(':')) {
      params.add(_identifier('a parameter name'));
      if (_isOp('=')) {
        _advance();
        defaults.add(_expr());
      } else {
        defaults.add(null);
      }
      if (_isOp(',')) {
        _advance();
      } else {
        break;
      }
    }
    _expectOp(':');
    final body = _expr();
    return Lambda(start.line, _srcFrom(start), params, defaults, body);
  }

  Expr _or() {
    final start = _cur;
    var left = _and();
    while (_isKw('or')) {
      _advance();
      final right = _and();
      left = BoolOp(start.line, _srcFrom(start), 'or', left, right);
    }
    return left;
  }

  Expr _and() {
    final start = _cur;
    var left = _not();
    while (_isKw('and')) {
      _advance();
      final right = _not();
      left = BoolOp(start.line, _srcFrom(start), 'and', left, right);
    }
    return left;
  }

  Expr _not() {
    final start = _cur;
    if (_isKw('not')) {
      _advance();
      final operand = _not();
      return UnaryOp(start.line, _srcFrom(start), 'not', operand);
    }
    return _comparison();
  }

  Expr _comparison() {
    final start = _cur;
    final left = _bitOr();
    final ops = <String>[];
    final rights = <Expr>[];
    while (true) {
      String? op;
      if (_cur.type == TokType.op &&
          const {'<', '>', '<=', '>=', '==', '!='}.contains(_cur.text)) {
        op = _advance().text;
      } else if (_isKw('in')) {
        _advance();
        op = 'in';
      } else if (_isKw('not') &&
          _peek(1).type == TokType.name &&
          _peek(1).text == 'in') {
        _advance();
        _advance();
        op = 'not in';
      } else if (_isKw('is')) {
        _advance();
        if (_isKw('not')) {
          _advance();
          op = 'is not';
        } else {
          op = 'is';
        }
      } else {
        break;
      }
      ops.add(op);
      rights.add(_bitOr());
    }
    if (ops.isEmpty) return left;
    return Compare(start.line, _srcFrom(start), left, ops, rights);
  }

  Expr _bitOr() {
    final start = _cur;
    var left = _bitXor();
    while (_isOp('|')) {
      _advance();
      final right = _bitXor();
      left = BinOp(start.line, _srcFrom(start), '|', left, right);
    }
    return left;
  }

  Expr _bitXor() {
    final start = _cur;
    var left = _bitAnd();
    while (_isOp('^')) {
      _advance();
      final right = _bitAnd();
      left = BinOp(start.line, _srcFrom(start), '^', left, right);
    }
    return left;
  }

  Expr _bitAnd() {
    final start = _cur;
    var left = _shift();
    while (_isOp('&')) {
      _advance();
      final right = _shift();
      left = BinOp(start.line, _srcFrom(start), '&', left, right);
    }
    return left;
  }

  Expr _shift() {
    final start = _cur;
    var left = _add();
    while (_isOp('<<') || _isOp('>>')) {
      final op = _advance().text;
      final right = _add();
      left = BinOp(start.line, _srcFrom(start), op, left, right);
    }
    return left;
  }

  Expr _add() {
    final start = _cur;
    var left = _mul();
    while (_isOp('+') || _isOp('-')) {
      final op = _advance().text;
      final right = _mul();
      left = BinOp(start.line, _srcFrom(start), op, left, right);
    }
    return left;
  }

  Expr _mul() {
    final start = _cur;
    var left = _unary();
    while (_isOp('*') || _isOp('/') || _isOp('//') || _isOp('%')) {
      final op = _advance().text;
      final right = _unary();
      left = BinOp(start.line, _srcFrom(start), op, left, right);
    }
    return left;
  }

  Expr _unary() {
    final start = _cur;
    if (_isOp('-') || _isOp('+') || _isOp('~')) {
      final op = _advance().text;
      final operand = _unary();
      return UnaryOp(start.line, _srcFrom(start), op, operand);
    }
    return _power();
  }

  Expr _power() {
    final start = _cur;
    final base = _postfix();
    if (_isOp('**')) {
      _advance();
      final exponent = _unary();
      return BinOp(start.line, _srcFrom(start), '**', base, exponent);
    }
    return base;
  }

  /// Atom followed by calls, [index] and .attribute
  Expr _postfix() {
    final start = _cur;
    var e = _atom();
    while (true) {
      if (_isOp('(')) {
        _advance();
        final args = <Expr>[];
        final kwargs = <String, Expr>{};
        while (!_isOp(')')) {
          if (_isOp('*') || _isOp('**')) {
            throw _err('*args and **kwargs are not supported yet');
          }
          if (_cur.type == TokType.name &&
              !_reserved.contains(_cur.text) &&
              _peek(1).type == TokType.op &&
              _peek(1).text == '=') {
            final key = _advance().text;
            _advance(); // =
            kwargs[key] = _expr();
          } else {
            final argStart = _cur;
            final arg = _expr();
            if (_isKw('for')) {
              // Generator expression as the only argument: sum(x for x in a)
              final clauses = _compClauses();
              args.add(Comp(argStart.line, _srcFrom(argStart), 'gen', arg, null, clauses));
            } else {
              args.add(arg);
            }
          }
          if (_isOp(',')) {
            _advance();
          } else {
            break;
          }
        }
        _expectOp(')');
        e = Call(start.line, _srcFrom(start), e, args, kwargs);
      } else if (_isOp('[')) {
        _advance();
        final index = _subscriptIndex();
        _expectOp(']');
        e = Subscript(start.line, _srcFrom(start), e, index);
      } else if (_isOp('.')) {
        _advance();
        if (_cur.type != TokType.name) {
          throw _err("Expected a name after '.'");
        }
        final name = _advance().text;
        e = Attribute(start.line, _srcFrom(start), e, name);
      } else {
        break;
      }
    }
    return e;
  }

  /// The part inside [ ]: an index, a tuple index or a slice.
  Expr _subscriptIndex() {
    final first = _cur;
    Expr? lower;
    Expr? upper;
    Expr? step;
    if (!_isOp(':')) {
      lower = _exprList();
      if (!_isOp(':')) return lower;
    }
    _advance(); // the first ':'
    if (!_isOp(':') && !_isOp(']')) upper = _expr();
    if (_isOp(':')) {
      _advance();
      if (!_isOp(']')) step = _expr();
    }
    return SliceExpr(first.line, _srcFrom(first), lower, upper, step);
  }

  /// for x in items if condition ... (used by comprehensions)
  List<CompClause> _compClauses() {
    final out = <CompClause>[];
    while (_isKw('for')) {
      _advance();
      final start = _cur;
      final targets = <Expr>[_postfix()];
      while (_isOp(',')) {
        _advance();
        targets.add(_postfix());
      }
      final Expr target = targets.length == 1
          ? targets.first
          : TupleLit(start.line, _srcFrom(start), targets);
      _checkTarget(target);
      if (!_isKw('in')) throw _err("Expected 'in' in the comprehension");
      _advance();
      final iter = _or();
      final conds = <Expr>[];
      while (_isKw('if')) {
        _advance();
        conds.add(_or());
      }
      out.add(CompClause(target, iter, conds));
    }
    return out;
  }

  // ------------------------------ strings ------------------------------

  String _unescape(String s) {
    if (!s.contains('\\')) return s;
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '\\' && i + 1 < s.length) {
        final nx = s[i + 1];
        i++;
        if (nx == 'n') {
          b.write('\n');
        } else if (nx == 't') {
          b.write('\t');
        } else if (nx == 'r') {
          b.write('\r');
        } else if (nx == '\\' || nx == "'" || nx == '"') {
          b.write(nx);
        } else {
          b.write('\\');
          b.write(nx);
        }
      } else {
        b.write(c);
      }
    }
    return b.toString();
  }

  Expr _parseSubExpr(String text, int line) {
    final trimmed = text.trim().replaceAll('\n', ' ');
    if (trimmed.isEmpty) {
      throw PyError(line, 'f-string: empty expression is not allowed');
    }
    final p = Parser(trimmed, firstLine: line);
    return p.parseExpressionOnly();
  }

  /// Splits the text of an f-string into plain text and {fields}.
  List<Object> _fstringParts(Token t, bool raw) {
    final s = t.text;
    final parts = <Object>[];
    final lit = StringBuffer();
    var i = 0;

    void flush() {
      if (lit.isNotEmpty) {
        parts.add(raw ? lit.toString() : _unescape(lit.toString()));
        lit.clear();
      }
    }

    while (i < s.length) {
      final c = s[i];
      if (c == '{') {
        if (i + 1 < s.length && s[i + 1] == '{') {
          lit.write('{');
          i += 2;
          continue;
        }
        var depth = 0;
        var j = i + 1;
        String? quote;
        var exprEnd = -1;
        var specStart = -1;
        while (j < s.length) {
          final ch = s[j];
          if (quote != null) {
            if (ch == quote) quote = null;
            j++;
            continue;
          }
          if (ch == '"' || ch == "'") {
            quote = ch;
            j++;
            continue;
          }
          if (ch == '(' || ch == '[' || ch == '{') {
            depth++;
          } else if (ch == ')' || ch == ']') {
            depth--;
          } else if (ch == '}') {
            if (depth == 0) break;
            depth--;
          } else if (ch == ':' && depth == 0 && exprEnd < 0) {
            exprEnd = j;
            specStart = j + 1;
          }
          j++;
        }
        if (j >= s.length) {
          throw PyError(t.line, "f-string: expecting '}'");
        }
        var exprText =
            exprEnd >= 0 ? s.substring(i + 1, exprEnd) : s.substring(i + 1, j);
        final spec = specStart >= 0 ? s.substring(specStart, j) : '';
        String? conv;
        final ct = exprText.trim();
        if (ct.length > 2 &&
            ct[ct.length - 2] == '!' &&
            (ct.endsWith('r') || ct.endsWith('s') || ct.endsWith('a'))) {
          conv = ct.substring(ct.length - 1);
          exprText = ct.substring(0, ct.length - 2);
        }
        flush();
        parts.add(FStringField(_parseSubExpr(exprText, t.line), spec, conv));
        i = j + 1;
        continue;
      }
      if (c == '}') {
        if (i + 1 < s.length && s[i + 1] == '}') {
          lit.write('}');
          i += 2;
          continue;
        }
        throw PyError(t.line, "f-string: single '}' is not allowed");
      }
      lit.write(c);
      i++;
    }
    flush();
    return parts;
  }

  // ------------------------------- atoms -------------------------------

  Expr _atom() {
    final t = _cur;

    if (t.type == TokType.number) {
      _advance();
      final isFloat =
          t.text.contains('.') || t.text.contains('e') || t.text.contains('E');
      final Object? value =
          isFloat ? double.tryParse(t.text) : int.tryParse(t.text);
      if (value == null) throw PyError(t.line, 'Invalid number ${t.text}');
      return Literal(t.line, t.text, value);
    }

    if (t.type == TokType.string) {
      final first = t;
      final parts = <Object>[];
      var hasF = false;
      while (_cur.type == TokType.string) {
        final st = _advance();
        if (st.prefix.contains('f')) {
          hasF = true;
          parts.addAll(_fstringParts(st, st.prefix.contains('r')));
        } else {
          parts.add(st.text);
        }
      }
      final text = _srcFrom(first);
      if (!hasF) {
        return Literal(first.line, text, parts.map((e) => e as String).join());
      }
      return JoinedStr(first.line, text, parts);
    }

    if (t.type == TokType.name) {
      if (t.text == 'True') {
        _advance();
        return Literal(t.line, 'True', true);
      }
      if (t.text == 'False') {
        _advance();
        return Literal(t.line, 'False', false);
      }
      if (t.text == 'None') {
        _advance();
        return Literal(t.line, 'None', null);
      }
      if (_reserved.contains(t.text)) {
        throw PyError(t.line, "'${t.text}' is not supported here");
      }
      _advance();
      return Name(t.line, t.text, t.text);
    }

    if (t.type == TokType.op) {
      if (t.text == '(') {
        _advance();
        if (_isOp(')')) {
          _advance();
          return TupleLit(t.line, '()', <Expr>[]);
        }
        final inner = _cur;
        final e = _exprList();
        if (_isKw('for')) {
          final clauses = _compClauses();
          _expectOp(')');
          return Comp(t.line, _srcFrom(t), 'gen', e, null, clauses);
        }
        _expectOp(')');
        if (e is Name || e is Literal) return e;
        // Keep the text with brackets for explanations.
        return _withSrc(e, src.substring(t.start, tokens[_p - 1].end), inner);
      }
      if (t.text == '[') {
        _advance();
        final items = <Expr>[];
        while (!_isOp(']')) {
          final item = _expr();
          if (_isKw('for')) {
            final clauses = _compClauses();
            _expectOp(']');
            return Comp(t.line, _srcFrom(t), 'list', item, null, clauses);
          }
          items.add(item);
          if (_isOp(',')) {
            _advance();
          } else {
            break;
          }
        }
        _expectOp(']');
        return ListLit(t.line, _srcFrom(t), items);
      }
      if (t.text == '{') {
        return _braceAtom();
      }
    }

    if (t.type == TokType.newline || t.type == TokType.eof) {
      throw PyError(t.line, 'Unexpected end of line');
    }
    throw PyError(t.line, "Unexpected '${t.text}'");
  }

  // Keeps the tree as it is. The brackets are only for the reader, so the
  // original source text of the inner expression is kept.
  Expr _withSrc(Expr e, String text, Token inner) => e;

  /// { ... } is a dictionary, a set or a comprehension.
  Expr _braceAtom() {
    final t = _advance(); // {
    if (_isOp('}')) {
      _advance();
      return DictLit(t.line, '{}', <Expr>[], <Expr>[]);
    }
    final first = _expr();
    if (_isOp(':')) {
      // dictionary
      _advance();
      final firstValue = _expr();
      if (_isKw('for')) {
        final clauses = _compClauses();
        _expectOp('}');
        return Comp(t.line, _srcFrom(t), 'dict', first, firstValue, clauses);
      }
      final keys = <Expr>[first];
      final values = <Expr>[firstValue];
      while (_isOp(',')) {
        _advance();
        if (_isOp('}')) break;
        keys.add(_expr());
        _expectOp(':');
        values.add(_expr());
      }
      _expectOp('}');
      return DictLit(t.line, _srcFrom(t), keys, values);
    }
    // set
    if (_isKw('for')) {
      final clauses = _compClauses();
      _expectOp('}');
      return Comp(t.line, _srcFrom(t), 'set', first, null, clauses);
    }
    final items = <Expr>[first];
    while (_isOp(',')) {
      _advance();
      if (_isOp('}')) break;
      items.add(_expr());
    }
    _expectOp('}');
    return SetLit(t.line, _srcFrom(t), items);
  }
}