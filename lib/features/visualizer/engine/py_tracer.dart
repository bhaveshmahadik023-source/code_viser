import 'dart:math' as math;

import 'py_ast.dart';
import 'py_error.dart';
import 'py_parser.dart';
import 'trace_models.dart';

/// Biggest whole number we allow (safe on web too).
const int _maxInt = 9007199254740991;

/// A lazy range(...) value.
class _RangeVal {
  _RangeVal(this.start, this.stop, this.step);

  final int start;
  final int stop;
  final int step;

  int get length {
    if (step > 0) {
      return stop > start ? (stop - start + step - 1) ~/ step : 0;
    }
    return start > stop ? (start - stop + (-step) - 1) ~/ (-step) : 0;
  }

  int at(int i) => start + i * step;
}

/// Local variables of one function call (or the main program).
class _Frame {
  _Frame(this.label);

  final String label;
  final Map<String, dynamic> vars = <String, dynamic>{};
}

/// An index expression like "j + 1" that is used as arr[j + 1].
class _IndexSpec {
  _IndexSpec(this.array, this.index, this.label);

  final String array;
  final Expr index;
  final String label;
}

/// Collects what an assignment did, to write the explanation.
class _AssignLog {
  final List<String> descs = <String>[];
  bool allNew = true;
}

enum _Flow { normal, brk, cont, ret }

const _builtinNames = {
  'print', 'len', 'range', 'int', 'float', 'str', 'abs', 'min', 'max', //
  'sum', 'list', 'enumerate', 'round',
};

/// Runs the user's Python code and records every step.
/// It really executes the code, so the steps are real (not fake).
class PyTracer {
  PyTracer(this.source) : _lines = source.split('\n');

  final String source;
  final List<String> _lines;

  /// Safety limits, so an infinite loop cannot freeze the app.
  static const int maxSteps = 1500;
  static const int maxDepth = 60;

  final List<TraceStep> _steps = <TraceStep>[];
  final List<_Frame> _stack = <_Frame>[];
  final Map<String, FuncDef> _funcs = <String, FuncDef>{};
  final List<String> _out = <String>[];

  // Array usage in the current statement (for the colors).
  final Map<String, Set<int>> _reads = <String, Set<int>>{};
  final Map<String, Set<int>> _writes = <String, Set<int>>{};
  bool _tracking = true;

  // Information used to draw pointers (i, j, low, mid, high ...).
  final Set<String> _indexVars = <String>{};
  final Map<String, Set<String>> _varArrays = <String, Set<String>>{};
  final List<_IndexSpec> _exprSpecs = <_IndexSpec>[];

  // Small helpers for explanations.
  String? _note;
  String? _lastCompare;
  dynamic _retVal;
  bool _started = false;

  // ------------------------------- run ---------------------------------

  TraceResult run() {
    TraceError? error;
    try {
      final program = Parser(source).parseProgram();
      _collectInfo(program);
      _stack.add(_Frame('main'));
      _started = true;
      _execBlock(program);
      _emit(0, 'End of program', 'The program finished running.');
    } on PyError catch (e) {
      error = TraceError(e.line, e.message);
      if (_started && e.line != null) {
        try {
          _emit(e.line!, _lineText(e.line!), 'Error: ${e.message}',
              force: true);
        } catch (_) {
          // Ignore problems while saving the error step.
        }
      }
    } catch (e) {
      error = TraceError(null, 'Internal error: $e');
    }
    return TraceResult(steps: _steps, error: error);
  }

  String _lineText(int line) =>
      (line >= 1 && line <= _lines.length) ? _lines[line - 1].trim() : '';

  // ---------------------------- pointer info ---------------------------

  bool _isSimple(Expr e) {
    if (e is Name) return true;
    if (e is Literal) return e.value is int;
    if (e is BinOp) return _isSimple(e.left) && _isSimple(e.right);
    if (e is UnaryOp) return e.op != 'not' && _isSimple(e.operand);
    return false;
  }

  void _simpleNames(Expr e, Set<String> out) {
    if (e is Name) {
      out.add(e.id);
    } else if (e is BinOp) {
      _simpleNames(e.left, out);
      _simpleNames(e.right, out);
    } else if (e is UnaryOp) {
      _simpleNames(e.operand, out);
    }
  }

  void _collectInfo(List<Stmt> program) {
    final edges = <List<String>>[]; // [target, name used in value]

    void addEdges(Expr target, Expr value) {
      if (target is Name && _isSimple(value)) {
        final names = <String>{};
        _simpleNames(value, names);
        for (final n in names) {
          edges.add([target.id, n]);
        }
      }
    }

    void walkExpr(Expr e) {
      if (e is Subscript) {
        final t = e.target;
        final idx = e.index;
        if (t is Name && _isSimple(idx)) {
          final names = <String>{};
          _simpleNames(idx, names);
          if (names.isNotEmpty) {
            for (final n in names) {
              _indexVars.add(n);
              _varArrays.putIfAbsent(n, () => <String>{}).add(t.id);
            }
            if (idx is! Name) {
              _exprSpecs
                  .add(_IndexSpec(t.id, idx, idx.src.replaceAll(' ', '')));
            }
          }
        }
        walkExpr(t);
        walkExpr(idx);
      } else if (e is BinOp) {
        walkExpr(e.left);
        walkExpr(e.right);
      } else if (e is UnaryOp) {
        walkExpr(e.operand);
      } else if (e is BoolOp) {
        walkExpr(e.left);
        walkExpr(e.right);
      } else if (e is Compare) {
        walkExpr(e.left);
        for (final r in e.rights) {
          walkExpr(r);
        }
      } else if (e is Call) {
        walkExpr(e.func);
        for (final a in e.args) {
          walkExpr(a);
        }
      } else if (e is Attribute) {
        walkExpr(e.obj);
      } else if (e is ListLit) {
        for (final i in e.items) {
          walkExpr(i);
        }
      } else if (e is TupleLit) {
        for (final i in e.items) {
          walkExpr(i);
        }
      } else if (e is IfExp) {
        walkExpr(e.test);
        walkExpr(e.body);
        walkExpr(e.orelse);
      }
    }

    void walkBlock(List<Stmt> body) {
      for (final s in body) {
        walkStmt(s, walkExpr, addEdges, walkBlock);
      }
    }

    walkBlock(program);

    // Names connected by simple assignments share the "index variable" role.
    // Example: mid = (low + high) // 2 makes low and high pointers too.
    var changed = true;
    var rounds = 0;
    while (changed && rounds < 10) {
      changed = false;
      rounds++;
      for (final edge in edges) {
        final t = edge[0];
        final n = edge[1];
        if (_indexVars.contains(t) && !_indexVars.contains(n)) {
          _indexVars.add(n);
          changed = true;
        } else if (_indexVars.contains(n) && !_indexVars.contains(t)) {
          _indexVars.add(t);
          changed = true;
        }
      }
    }
  }

  void walkStmt(
    Stmt s,
    void Function(Expr) walkExpr,
    void Function(Expr, Expr) addEdges,
    void Function(List<Stmt>) walkBlock,
  ) {
    if (s is ExprStmt) {
      walkExpr(s.expr);
    } else if (s is Assign) {
      walkExpr(s.value);
      walkExpr(s.target);
      final t = s.target;
      final v = s.value;
      if (t is TupleLit && v is TupleLit && t.items.length == v.items.length) {
        for (var i = 0; i < t.items.length; i++) {
          addEdges(t.items[i], v.items[i]);
        }
      } else {
        addEdges(t, v);
      }
    } else if (s is AugAssign) {
      walkExpr(s.value);
      walkExpr(s.target);
      addEdges(s.target, s.value);
    } else if (s is IfStmt) {
      walkExpr(s.test);
      walkBlock(s.body);
      walkBlock(s.orelse);
    } else if (s is WhileStmt) {
      walkExpr(s.test);
      walkBlock(s.body);
    } else if (s is ForStmt) {
      walkExpr(s.iter);
      walkExpr(s.target);
      walkBlock(s.body);
    } else if (s is FuncDef) {
      walkBlock(s.body);
    } else if (s is ReturnStmt) {
      final v = s.value;
      if (v != null) walkExpr(v);
    }
  }

  Map<String, Map<int, String>> _pointers(_Frame frame) {
    final raw = <String, Map<int, List<String>>>{};

    void put(String arr, int idx, String label) {
      final labels =
          raw.putIfAbsent(arr, () => <int, List<String>>{}).putIfAbsent(
                idx,
                () => <String>[],
              );
      if (!labels.contains(label)) labels.add(label);
    }

    final listNames = <String>[
      for (final e in frame.vars.entries)
        if (e.value is List) e.key,
    ];

    // Plain variables such as i, j, low, mid, high.
    frame.vars.forEach((name, value) {
      if (value is int && _indexVars.contains(name)) {
        final direct = _varArrays[name];
        final targets = (direct == null || direct.isEmpty)
            ? listNames
            : direct.where(listNames.contains).toList();
        for (final arr in targets) {
          final list = frame.vars[arr] as List;
          if (value >= 0 && value < list.length) {
            put(arr, value, name);
          }
        }
      }
    });

    // Expressions such as j + 1.
    for (final spec in _exprSpecs) {
      final list = frame.vars[spec.array];
      if (list is! List) continue;
      final before = _tracking;
      _tracking = false;
      try {
        final v = _eval(spec.index);
        if (v is int && v >= 0 && v < list.length) {
          put(spec.array, v, spec.label);
        }
      } catch (_) {
        // The expression cannot be calculated now. Ignore it.
      } finally {
        _tracking = before;
      }
    }

    return {
      for (final e in raw.entries)
        e.key: {
          for (final p in e.value.entries) p.key: p.value.join(', '),
        },
    };
  }

  // ------------------------------ snapshots ----------------------------

  String _repr(dynamic v) {
    if (v == null) return 'None';
    if (v is bool) return v ? 'True' : 'False';
    if (v is String) return "'$v'";
    if (v is List) return '[${v.map(_repr).join(', ')}]';
    if (v is _RangeVal) {
      return v.step == 1
          ? 'range(${v.start}, ${v.stop})'
          : 'range(${v.start}, ${v.stop}, ${v.step})';
    }
    if (v is double) {
      if (v.isNaN) return 'nan';
      if (v.isInfinite) return v > 0 ? 'inf' : '-inf';
      return v.toString();
    }
    return '$v';
  }

  String _str(dynamic v) => v is String ? v : _repr(v);

  VarSnapshot _snapshot(String name, dynamic v) {
    if (v is List) {
      if (v.isNotEmpty && v.every((e) => e is List)) {
        return VarSnapshot(
          name: name,
          type: VarType.matrix,
          text: _repr(v),
          rows: [
            for (final row in v)
              [for (final cell in (row as List)) _repr(cell)],
          ],
        );
      }
      final allNumbers = v.isNotEmpty && v.every((e) => e is int || e is double);
      return VarSnapshot(
        name: name,
        type: VarType.list,
        text: _repr(v),
        items: [for (final e in v) _repr(e)],
        numbers: allNumbers
            ? [for (final e in v) (e as num).toDouble()]
            : null,
      );
    }
    return VarSnapshot(name: name, type: VarType.scalar, text: _repr(v));
  }

  String _frameLabel(_Frame f) =>
      f.label.length > 40 ? '${f.label.substring(0, 37)}...' : f.label;

  /// Saves one step.
  void _emit(
    int line,
    String statement,
    String explanation, {
    bool? condition,
    bool force = false,
  }) {
    if (!force && _steps.length >= maxSteps) {
      throw PyError(
        line,
        'Too many steps (more than $maxSteps). Is there an infinite loop?',
      );
    }
    final frame = _stack.last;
    final vars = <String, VarSnapshot>{
      for (final e in frame.vars.entries) e.key: _snapshot(e.key, e.value),
    };

    final marks = <String, Map<int, MarkKind>>{};
    _reads.forEach((array, indexes) {
      for (final i in indexes) {
        marks.putIfAbsent(array, () => <int, MarkKind>{})[i] = MarkKind.read;
      }
    });
    _writes.forEach((array, indexes) {
      for (final i in indexes) {
        marks.putIfAbsent(array, () => <int, MarkKind>{})[i] = MarkKind.write;
      }
    });
    _reads.clear();
    _writes.clear();

    _steps.add(TraceStep(
      number: _steps.length + 1,
      line: line,
      statement: statement,
      explanation: explanation,
      vars: vars,
      marks: marks,
      pointers: _pointers(frame),
      output: List<String>.of(_out),
      callStack: [for (final f in _stack) _frameLabel(f)],
      condition: condition,
    ));
  }

  // ----------------------------- statements ----------------------------

  _Flow _execBlock(List<Stmt> body) {
    for (final s in body) {
      final flow = _exec(s);
      if (flow != _Flow.normal) return flow;
    }
    return _Flow.normal;
  }

  _Flow _exec(Stmt s) {
    _note = null;
    final text = _lineText(s.line);

    if (s is Assign) {
      final value = _eval(s.value);
      final log = _AssignLog();
      _assign(s.target, value, s.line, log);
      _emit(s.line, text,
          '${log.allNew ? 'Created' : 'Updated'} ${log.descs.join(', ')}');
      return _Flow.normal;
    }

    if (s is AugAssign) {
      final current = _eval(s.target);
      final rhs = _eval(s.value);
      final result = _binop(s.op, current, rhs, s.line);
      final log = _AssignLog();
      _assign(s.target, result, s.line, log);
      _emit(s.line, text, 'Updated ${log.descs.join(', ')}');
      return _Flow.normal;
    }

    if (s is ExprStmt) {
      _eval(s.expr);
      _emit(s.line, text, _note ?? 'Ran ${s.expr.src}');
      return _Flow.normal;
    }

    if (s is IfStmt) {
      _lastCompare = null;
      final cond = _truthy(_eval(s.test));
      _emit(
        s.line,
        text,
        '${_lastCompare ?? s.test.src} is ${cond ? 'True, so the block runs' : 'False, so the block is skipped'}',
        condition: cond,
      );
      if (cond) {
        return _execBlock(s.body);
      }
      if (s.orelse.isNotEmpty) {
        final elseLine = s.elseLine;
        if (elseLine != null) {
          _emit(elseLine, _lineText(elseLine),
              'The condition was False, so the else block runs');
        }
        return _execBlock(s.orelse);
      }
      return _Flow.normal;
    }

    if (s is WhileStmt) {
      while (true) {
        _lastCompare = null;
        final cond = _truthy(_eval(s.test));
        _emit(
          s.line,
          text,
          '${_lastCompare ?? s.test.src} is ${cond ? 'True, so the loop body runs' : 'False, so the loop stops'}',
          condition: cond,
        );
        if (!cond) break;
        final flow = _execBlock(s.body);
        if (flow == _Flow.brk) break;
        if (flow == _Flow.ret) return flow;
      }
      return _Flow.normal;
    }

    if (s is ForStmt) {
      final it = _eval(s.iter);
      if (it is! List && it is! String && it is! _RangeVal) {
        throw PyError(s.line, "'${_typeName(it)}' object is not iterable");
      }
      int lengthNow() {
        if (it is List) return it.length;
        if (it is String) return it.length;
        return (it as _RangeVal).length;
      }

      dynamic itemAt(int i) {
        if (it is List) return it[i];
        if (it is String) return it[i];
        return (it as _RangeVal).at(i);
      }

      var broke = false;
      for (var idx = 0; idx < lengthNow(); idx++) {
        final log = _AssignLog();
        _assign(s.target, itemAt(idx), s.line, log);
        _emit(s.line, text,
            'Iteration ${idx + 1}: ${log.descs.join(', ')}');
        final flow = _execBlock(s.body);
        if (flow == _Flow.brk) {
          broke = true;
          break;
        }
        if (flow == _Flow.ret) return flow;
      }
      if (!broke) {
        _emit(s.line, text, 'No more items, so the for loop ends');
      }
      return _Flow.normal;
    }

    if (s is FuncDef) {
      _funcs[s.name] = s;
      _emit(s.line, text,
          'Function ${s.name}(${s.params.join(', ')}) is defined. It runs only when it is called.');
      return _Flow.normal;
    }

    if (s is ReturnStmt) {
      if (_stack.length <= 1) {
        throw PyError(s.line, "'return' is only allowed inside a function");
      }
      final v = s.value;
      _retVal = v == null ? null : _eval(v);
      _emit(s.line, text, 'Return ${_repr(_retVal)} to the caller');
      return _Flow.ret;
    }

    if (s is BreakStmt) {
      _emit(s.line, text, 'Break: leave the loop now');
      return _Flow.brk;
    }

    if (s is ContinueStmt) {
      _emit(s.line, text, 'Continue: skip to the next iteration');
      return _Flow.cont;
    }

    if (s is PassStmt) {
      _emit(s.line, text, 'Pass: do nothing');
      return _Flow.normal;
    }

    throw PyError(s.line, 'This statement is not supported yet');
  }

  // ----------------------------- assignment ----------------------------

  void _assign(Expr target, dynamic value, int line, _AssignLog log) {
    if (target is Name) {
      final frame = _stack.last;
      if (frame.vars.containsKey(target.id)) log.allNew = false;
      frame.vars[target.id] = value;
      log.descs.add('${target.id} = ${_repr(value)}');
      return;
    }

    if (target is Subscript) {
      final container = _eval(target.target);
      final idx = _eval(target.index);
      if (container is! List) {
        throw PyError(line,
            "'${_typeName(container)}' object does not support item assignment");
      }
      if (idx is! int) throw PyError(line, 'List index must be an integer');
      final norm = _normIndex(idx, container.length, line);
      container[norm] = value;
      log.allNew = false;
      final base = target.target;
      if (base is Name && _tracking) {
        _writes.putIfAbsent(base.id, () => <int>{}).add(norm);
      }
      log.descs.add('${target.target.src}[$norm] = ${_repr(value)}');
      return;
    }

    if (target is TupleLit) {
      if (value is! List) {
        throw PyError(line, 'Cannot unpack a ${_typeName(value)} value');
      }
      if (value.length != target.items.length) {
        throw PyError(line,
            'Cannot unpack ${value.length} values into ${target.items.length} names');
      }
      for (var i = 0; i < target.items.length; i++) {
        _assign(target.items[i], value[i], line, log);
      }
      return;
    }

    throw PyError(line, 'Cannot assign to this expression');
  }

  int _normIndex(int idx, int length, int line) {
    final norm = idx < 0 ? idx + length : idx;
    if (norm < 0 || norm >= length) {
      throw PyError(line, 'Index $idx is out of range (length is $length)');
    }
    return norm;
  }

  // ---------------------------- expressions ----------------------------

  dynamic _lookup(String id, int line) {
    final frame = _stack.last;
    if (frame.vars.containsKey(id)) return frame.vars[id];
    final global = _stack.first;
    if (global.vars.containsKey(id)) return global.vars[id];
    throw PyError(line, "Name '$id' is not defined");
  }

  dynamic _eval(Expr e) {
    if (e is Literal) return e.value;
    if (e is Name) return _lookup(e.id, e.line);

    if (e is ListLit) return <dynamic>[for (final i in e.items) _eval(i)];
    if (e is TupleLit) return <dynamic>[for (final i in e.items) _eval(i)];

    if (e is UnaryOp) {
      final v = _eval(e.operand);
      if (e.op == 'not') return !_truthy(v);
      final n = v is bool ? (v ? 1 : 0) : v;
      if (n is! num) {
        throw PyError(e.line, "Bad operand type for unary ${e.op}");
      }
      return e.op == '-' ? -n : n;
    }

    if (e is BinOp) {
      final l = _eval(e.left);
      final r = _eval(e.right);
      return _binop(e.op, l, r, e.line);
    }

    if (e is BoolOp) {
      final l = _eval(e.left);
      if (e.op == 'and') {
        return _truthy(l) ? _eval(e.right) : l;
      }
      return _truthy(l) ? l : _eval(e.right);
    }

    if (e is Compare) {
      var left = _eval(e.left);
      var result = true;
      for (var i = 0; i < e.ops.length; i++) {
        final right = _eval(e.rights[i]);
        final ok = _compareOp(e.ops[i], left, right, e.line);
        if (i == 0) {
          _lastCompare =
              '${_repr(left)} ${e.ops[i]} ${_repr(right)} (${e.src})';
        }
        if (!ok) {
          result = false;
          break;
        }
        left = right;
      }
      return result;
    }

    if (e is Subscript) {
      final container = _eval(e.target);
      final idx = _eval(e.index);
      if (idx is! int) throw PyError(e.line, 'Index must be an integer');
      int length;
      if (container is List) {
        length = container.length;
      } else if (container is String) {
        length = container.length;
      } else {
        throw PyError(
            e.line, "'${_typeName(container)}' object cannot be indexed");
      }
      final norm = _normIndex(idx, length, e.line);
      final base = e.target;
      if (_tracking && base is Name && container is List) {
        _reads.putIfAbsent(base.id, () => <int>{}).add(norm);
      }
      return container is List ? container[norm] : (container as String)[norm];
    }

    if (e is IfExp) {
      return _truthy(_eval(e.test)) ? _eval(e.body) : _eval(e.orelse);
    }

    if (e is Call) return _evalCall(e);

    if (e is Attribute) {
      throw PyError(e.line, 'Attributes are only supported in method calls');
    }

    throw PyError(e.line, 'This expression is not supported yet');
  }

  bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty;
    if (v is List) return v.isNotEmpty;
    if (v is _RangeVal) return v.length > 0;
    return true;
  }

  String _typeName(dynamic v) {
    if (v == null) return 'NoneType';
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'float';
    if (v is String) return 'str';
    if (v is List) return 'list';
    if (v is _RangeVal) return 'range';
    return 'object';
  }

  num _checkNum(num v, int line) {
    if (v is int && v.abs() > _maxInt) {
      throw PyError(line,
          'Number is too big for this visualizer (limit is $_maxInt)');
    }
    return v;
  }

  int _floorDiv(int a, int b) {
    var q = a ~/ b;
    if ((a % b != 0) && ((a < 0) != (b < 0))) q -= 1;
    return q;
  }

  int _mod(int a, int b) {
    var r = a % b;
    if (r != 0 && b < 0) r += b;
    return r;
  }

  dynamic _binop(String op, dynamic a, dynamic b, int line) {
    final x = a is bool ? (a ? 1 : 0) : a;
    final y = b is bool ? (b ? 1 : 0) : b;

    if (x is num && y is num) {
      switch (op) {
        case '+':
          return _checkNum(x + y, line);
        case '-':
          return _checkNum(x - y, line);
        case '*':
          return _checkNum(x * y, line);
        case '/':
          if (y == 0) throw PyError(line, 'Division by zero');
          return x / y;
        case '//':
          if (y == 0) throw PyError(line, 'Division by zero');
          if (x is int && y is int) return _floorDiv(x, y);
          return (x / y).floorToDouble();
        case '%':
          if (y == 0) throw PyError(line, 'Modulo by zero');
          if (x is int && y is int) return _mod(x, y);
          return x - y * (x / y).floorToDouble();
        case '**':
          if (x is int && y is int && y >= 0) {
            if (y > 10000) throw PyError(line, 'Exponent is too large');
            num result = 1;
            for (var i = 0; i < y; i++) {
              result = _checkNum(result * x, line);
            }
            return result;
          }
          return math.pow(x, y);
      }
    }

    if (op == '+') {
      if (a is String && b is String) return a + b;
      if (a is List && b is List) return <dynamic>[...a, ...b];
    }
    if (op == '*') {
      if (a is String && y is int) return y <= 0 ? '' : a * y;
      if (x is int && b is String) return x <= 0 ? '' : b * x;
      if (a is List && y is int) {
        return <dynamic>[
          for (var i = 0; i < y; i++) ...a,
        ];
      }
      if (x is int && b is List) {
        return <dynamic>[
          for (var i = 0; i < x; i++) ...b,
        ];
      }
    }
    throw PyError(line,
        "Cannot use '$op' with ${_typeName(a)} and ${_typeName(b)}");
  }

  bool _eq(dynamic a, dynamic b) {
    final x = a is bool ? (a ? 1 : 0) : a;
    final y = b is bool ? (b ? 1 : 0) : b;
    if (x is num && y is num) return x == y;
    if (x is List && y is List) {
      if (x.length != y.length) return false;
      for (var i = 0; i < x.length; i++) {
        if (!_eq(x[i], y[i])) return false;
      }
      return true;
    }
    return x == y;
  }

  bool _contains(dynamic container, dynamic item, int line) {
    if (container is List) return container.any((e) => _eq(e, item));
    if (container is String) {
      if (item is! String) {
        throw PyError(line, "'in <string>' needs a string on the left");
      }
      return container.contains(item);
    }
    if (container is _RangeVal) {
      for (var i = 0; i < container.length; i++) {
        if (container.at(i) == item) return true;
      }
      return false;
    }
    throw PyError(line, "Argument of type '${_typeName(container)}' is not iterable");
  }

  bool _compareOp(String op, dynamic a, dynamic b, int line) {
    switch (op) {
      case '==':
        return _eq(a, b);
      case '!=':
        return !_eq(a, b);
      case 'in':
        return _contains(b, a, line);
      case 'not in':
        return !_contains(b, a, line);
      case 'is':
        return (a == null && b == null) || identical(a, b) || (a is bool && b is bool && a == b);
      case 'is not':
        return !((a == null && b == null) || identical(a, b) || (a is bool && b is bool && a == b));
    }
    final x = a is bool ? (a ? 1 : 0) : a;
    final y = b is bool ? (b ? 1 : 0) : b;
    int c;
    if (x is num && y is num) {
      c = x.compareTo(y);
    } else if (x is String && y is String) {
      c = x.compareTo(y);
    } else {
      throw PyError(line,
          "'$op' is not supported between ${_typeName(a)} and ${_typeName(b)}");
    }
    switch (op) {
      case '<':
        return c < 0;
      case '<=':
        return c <= 0;
      case '>':
        return c > 0;
      case '>=':
        return c >= 0;
    }
    throw PyError(line, "Unknown operator '$op'");
  }

  // ------------------------------- calls -------------------------------

  dynamic _evalCall(Call c) {
    final f = c.func;

    if (f is Attribute) {
      return _callMethod(c, f);
    }

    if (f is Name) {
      final args = <dynamic>[for (final a in c.args) _eval(a)];
      final user = _funcs[f.id];
      if (user != null) return _callUser(user, args, c);
      if (_builtinNames.contains(f.id)) return _builtin(f.id, args, c);
      throw PyError(c.line, "Name '${f.id}' is not defined");
    }

    throw PyError(c.line, 'This kind of call is not supported yet');
  }

  dynamic _callUser(FuncDef def, List<dynamic> args, Call c) {
    if (args.length != def.params.length) {
      throw PyError(c.line,
          '${def.name}() needs ${def.params.length} argument(s) but got ${args.length}');
    }
    if (_stack.length >= maxDepth) {
      throw PyError(c.line, 'Recursion is too deep (limit is $maxDepth calls)');
    }
    _reads.clear();
    _writes.clear();
    final frame = _Frame('${def.name}(${args.map(_repr).join(', ')})');
    for (var i = 0; i < args.length; i++) {
      frame.vars[def.params[i]] = args[i];
    }
    _stack.add(frame);
    _emit(def.line, _lineText(def.line),
        'Call ${frame.label}: a new frame is created with its own variables');
    final flow = _execBlock(def.body);
    final result = flow == _Flow.ret ? _retVal : null;
    _retVal = null;
    _stack.removeLast();
    _note = 'Back from ${def.name}() with result ${_repr(result)}';
    return result;
  }

  void _needArgs(Call c, List<dynamic> args, int count, String name) {
    if (args.length != count) {
      throw PyError(c.line, '$name() needs $count argument(s) but got ${args.length}');
    }
  }

  int _lenOf(dynamic v, int line) {
    if (v is List) return v.length;
    if (v is String) return v.length;
    if (v is _RangeVal) return v.length;
    throw PyError(line, "Object of type '${_typeName(v)}' has no len()");
  }

  List<dynamic> _toList(dynamic v, int line) {
    if (v is List) return List<dynamic>.of(v);
    if (v is String) return v.split('');
    if (v is _RangeVal) return [for (var i = 0; i < v.length; i++) v.at(i)];
    throw PyError(line, "'${_typeName(v)}' object is not iterable");
  }

  dynamic _builtin(String name, List<dynamic> args, Call c) {
    final line = c.line;
    switch (name) {
      case 'print':
        final text = args.map(_str).join(' ');
        _out.add(text);
        _note = 'Printed: $text';
        return null;

      case 'len':
        _needArgs(c, args, 1, 'len');
        return _lenOf(args[0], line);

      case 'range':
        if (args.isEmpty || args.length > 3 || args.any((a) => a is! int)) {
          throw PyError(line, 'range() needs 1 to 3 whole numbers');
        }
        final ints = args.cast<int>();
        final start = ints.length == 1 ? 0 : ints[0];
        final stop = ints.length == 1 ? ints[0] : ints[1];
        final step = ints.length == 3 ? ints[2] : 1;
        if (step == 0) throw PyError(line, 'range() step cannot be 0');
        return _RangeVal(start, stop, step);

      case 'int':
        _needArgs(c, args, 1, 'int');
        final iv = args[0];
        if (iv is bool) return iv ? 1 : 0;
        if (iv is int) return iv;
        if (iv is double) return iv.truncate();
        if (iv is String) {
          final parsedInt = int.tryParse(iv.trim());
          if (parsedInt == null) {
            throw PyError(line, "Cannot convert '$iv' to int");
          }
          return parsedInt;
        }
        throw PyError(line, "Cannot convert ${_typeName(iv)} to int");

      case 'float':
        _needArgs(c, args, 1, 'float');
        final fv = args[0];
        if (fv is bool) return fv ? 1.0 : 0.0;
        if (fv is num) return fv.toDouble();
        if (fv is String) {
          final parsedFloat = double.tryParse(fv.trim());
          if (parsedFloat == null) {
            throw PyError(line, "Cannot convert '$fv' to float");
          }
          return parsedFloat;
        }
        throw PyError(line, "Cannot convert ${_typeName(fv)} to float");

      case 'str':
        _needArgs(c, args, 1, 'str');
        return _str(args[0]);

      case 'abs':
        _needArgs(c, args, 1, 'abs');
        final av = args[0];
        if (av is num) return av.abs();
        throw PyError(line, 'abs() needs a number');

      case 'round':
        _needArgs(c, args, 1, 'round');
        final rv = args[0];
        if (rv is num) return rv.round();
        throw PyError(line, 'round() needs a number');

      case 'min':
      case 'max':
        final items = (args.length == 1 && args[0] is List)
            ? args[0] as List
            : args;
        if (items.isEmpty) throw PyError(line, '$name() needs at least one value');
        dynamic best = items.first;
        for (final item in items.skip(1)) {
          final better = name == 'min'
              ? _compareOp('<', item, best, line)
              : _compareOp('>', item, best, line);
          if (better) best = item;
        }
        return best;

      case 'sum':
        _needArgs(c, args, 1, 'sum');
        final sumList = _toList(args[0], line);
        num total = 0;
        for (final sumItem in sumList) {
          if (sumItem is! num) throw PyError(line, 'sum() needs numbers');
          total = _checkNum(total + sumItem, line);
        }
        return total;

      case 'list':
        _needArgs(c, args, 1, 'list');
        return _toList(args[0], line);

      case 'enumerate':
        _needArgs(c, args, 1, 'enumerate');
        final enumList = _toList(args[0], line);
        return <dynamic>[
          for (var i = 0; i < enumList.length; i++) <dynamic>[i, enumList[i]],
        ];
    }
    throw PyError(line, "Function '$name' is not supported yet");
  }

  dynamic _callMethod(Call c, Attribute a) {
    final obj = _eval(a.obj);
    final args = <dynamic>[for (final x in c.args) _eval(x)];
    final line = c.line;
    final base = a.obj;
    final arrName = base is Name ? base.id : null;

    if (obj is List) {
      switch (a.name) {
        case 'append':
          _needArgs(c, args, 1, 'append');
          obj.add(args[0]);
          if (_tracking && arrName != null) {
            _writes.putIfAbsent(arrName, () => <int>{}).add(obj.length - 1);
          }
          _note = 'Added ${_repr(args[0])} to the end of ${a.obj.src}';
          return null;

        case 'pop':
          if (obj.isEmpty) throw PyError(line, 'Cannot pop from an empty list');
          var popIdx = obj.length - 1;
          if (args.isNotEmpty) {
            final popGiven = args[0];
            if (popGiven is! int) throw PyError(line, 'pop() index must be an integer');
            popIdx = _normIndex(popGiven, obj.length, line);
          }
          final removed = obj.removeAt(popIdx);
          _note = 'Removed ${_repr(removed)} from ${a.obj.src}';
          return removed;

        case 'insert':
          _needArgs(c, args, 2, 'insert');
          final insGiven = args[0];
          if (insGiven is! int) throw PyError(line, 'insert() index must be an integer');
          var insIdx = insGiven < 0 ? insGiven + obj.length : insGiven;
          if (insIdx < 0) insIdx = 0;
          if (insIdx > obj.length) insIdx = obj.length;
          obj.insert(insIdx, args[1]);
          if (_tracking && arrName != null) {
            _writes.putIfAbsent(arrName, () => <int>{}).add(insIdx);
          }
          _note = 'Inserted ${_repr(args[1])} at index $insIdx of ${a.obj.src}';
          return null;

        case 'extend':
          _needArgs(c, args, 1, 'extend');
          obj.addAll(_toList(args[0], line));
          _note = 'Added all items to the end of ${a.obj.src}';
          return null;

        case 'reverse':
          final reversed = obj.reversed.toList();
          obj
            ..clear()
            ..addAll(reversed);
          if (_tracking && arrName != null) {
            _writes.putIfAbsent(arrName, () => <int>{}).addAll(
                  [for (var i = 0; i < obj.length; i++) i],
                );
          }
          _note = 'Reversed ${a.obj.src}';
          return null;

        case 'remove':
          _needArgs(c, args, 1, 'remove');
          final rmAt = obj.indexWhere((e) => _eq(e, args[0]));
          if (rmAt < 0) throw PyError(line, 'Value is not in the list');
          obj.removeAt(rmAt);
          _note = 'Removed ${_repr(args[0])} from ${a.obj.src}';
          return null;

        case 'index':
          _needArgs(c, args, 1, 'index');
          final ixAt = obj.indexWhere((e) => _eq(e, args[0]));
          if (ixAt < 0) throw PyError(line, 'Value is not in the list');
          return ixAt;

        case 'count':
          _needArgs(c, args, 1, 'count');
          return obj.where((e) => _eq(e, args[0])).length;
      }
      throw PyError(line, "Lists have no method '${a.name}' in this visualizer");
    }

    if (obj is String) {
      switch (a.name) {
        case 'upper':
          return obj.toUpperCase();
        case 'lower':
          return obj.toLowerCase();
        case 'strip':
          return obj.trim();
        case 'isdigit':
          return obj.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(obj);
        case 'isalpha':
          return obj.isNotEmpty && RegExp(r'^[A-Za-z]+$').hasMatch(obj);
        case 'replace':
          _needArgs(c, args, 2, 'replace');
          if (args[0] is! String || args[1] is! String) {
            throw PyError(line, 'replace() needs two strings');
          }
          return obj.replaceAll(args[0] as String, args[1] as String);
        case 'startswith':
          _needArgs(c, args, 1, 'startswith');
          return args[0] is String && obj.startsWith(args[0] as String);
        case 'endswith':
          _needArgs(c, args, 1, 'endswith');
          return args[0] is String && obj.endsWith(args[0] as String);
      }
      throw PyError(line, "Strings have no method '${a.name}' in this visualizer");
    }

    throw PyError(line, "'${_typeName(obj)}' has no method '${a.name}'");
  }
}