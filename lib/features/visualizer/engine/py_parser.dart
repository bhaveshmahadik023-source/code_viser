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

/// Words that start a statement we do not support yet.
const _unsupportedStatements = {
  'import', 'from', 'class', 'try', 'with', 'lambda', 'global', 'nonlocal',
  'del', 'assert', 'raise', 'yield', 'async', 'await', //
};

const _augOps = {'+=', '-=', '*=', '/=', '//=', '%=', '**='};

/// Reads tokens and builds the tree of statements.
class Parser {
  Parser(this.src) : tokens = tokenize(src);

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

  /// Source text from [start] to the last consumed token.
  String _srcFrom(Token start) => src.substring(start.start, tokens[_p - 1].end);

  void _endSimple() {
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

  Stmt _statement() {
    final t = _cur;
    if (t.type == TokType.name) {
      switch (t.text) {
        case 'if':
          return _ifStmt();
        case 'while':
          _advance();
          final test = _expr();
          final body = _suite();
          return WhileStmt(t.line, test, body);
        case 'for':
          return _forStmt();
        case 'def':
          return _funcDef();
        case 'return':
          _advance();
          Expr? value;
          if (_cur.type != TokType.newline && _cur.type != TokType.eof) {
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
        case 'elif':
        case 'else':
          throw PyError(t.line, "'${t.text}' without a matching 'if'");
      }
      if (_unsupportedStatements.contains(t.text)) {
        throw PyError(t.line, "'${t.text}' is not supported yet");
      }
    }
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
    return ForStmt(kw.line, target, iter, body);
  }

  Stmt _funcDef() {
    final kw = _advance();
    if (_cur.type != TokType.name || _reserved.contains(_cur.text)) {
      throw _err('Expected a function name');
    }
    final name = _advance().text;
    _expectOp('(');
    final params = <String>[];
    while (!_isOp(')')) {
      if (_cur.type != TokType.name || _reserved.contains(_cur.text)) {
        throw _err('Expected a parameter name');
      }
      params.add(_advance().text);
      if (_isOp('=')) {
        throw _err('Default parameter values are not supported yet');
      }
      if (_isOp(',')) {
        _advance();
      } else {
        break;
      }
    }
    _expectOp(')');
    final body = _suite();
    return FuncDef(kw.line, name, params, body);
  }

  Stmt _simpleStmt() {
    final startTok = _cur;
    final first = _exprList();
    Stmt s;
    if (_isOp('=')) {
      _advance();
      final value = _exprList();
      if (_isOp('=')) {
        throw _err('Chained assignment (a = b = c) is not supported yet');
      }
      _checkTarget(first);
      s = Assign(startTok.line, first, value);
    } else if (_cur.type == TokType.op && _augOps.contains(_cur.text)) {
      final raw = _advance().text;
      final op = raw.substring(0, raw.length - 1);
      final value = _expr();
      if (first is! Name && first is! Subscript) {
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
    if (t is Name || t is Subscript) return;
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
            _cur.text == ':');
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
    final left = _add();
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
      rights.add(_add());
    }
    if (ops.isEmpty) return left;
    return Compare(start.line, _srcFrom(start), left, ops, rights);
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
    if (_isOp('-') || _isOp('+')) {
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
        while (!_isOp(')')) {
          args.add(_expr());
          if (_isOp('=')) {
            throw _err('Keyword arguments (like end=) are not supported yet');
          }
          if (_isOp(',')) {
            _advance();
          } else {
            break;
          }
        }
        _expectOp(')');
        e = Call(start.line, _srcFrom(start), e, args);
      } else if (_isOp('[')) {
        _advance();
        if (_isOp(':')) throw _err('Slicing is not supported yet');
        final index = _exprList();
        if (_isOp(':')) throw _err('Slicing is not supported yet');
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
      _advance();
      return Literal(t.line, src.substring(t.start, t.end), t.text);
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
        final e = _exprList();
        _expectOp(')');
        return e;
      }
      if (t.text == '[') {
        _advance();
        final items = <Expr>[];
        while (!_isOp(']')) {
          items.add(_expr());
          if (_isKw('for')) {
            throw _err('List comprehensions are not supported yet');
          }
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
        throw PyError(t.line, 'Dictionaries and sets are not supported yet');
      }
    }

    if (t.type == TokType.newline || t.type == TokType.eof) {
      throw PyError(t.line, 'Unexpected end of line');
    }
    throw PyError(t.line, "Unexpected '${t.text}'");
  }
}