import 'dart:collection';
import 'dart:math' as math;

import 'py_ast.dart';
import 'py_error.dart';
import 'py_parser.dart';
import 'trace_models.dart';

/// Biggest whole number we allow (safe on web too).
const int _maxInt = 9007199254740991;

// ============================== value classes ==============================

class _NoDefault {
  const _NoDefault();
}

const _noDefault = _NoDefault();

/// A tuple. It is a list that cannot be changed.
class _Tuple extends ListBase<dynamic> {
  _Tuple(this._items);

  final List<dynamic> _items;

  @override
  int get length => _items.length;

  @override
  set length(int newLength) {
    throw UnsupportedError('A tuple cannot change its size');
  }

  @override
  dynamic operator [](int index) => _items[index];

  @override
  void operator []=(int index, dynamic value) {
    throw UnsupportedError('A tuple cannot be changed');
  }

  @override
  bool operator ==(Object other) {
    if (other is! _Tuple || other.length != length) return false;
    for (var i = 0; i < length; i++) {
      if (_items[i] != other._items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_items);
}

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

/// The value of a[lo:hi:step].
class _SliceVal {
  _SliceVal(this.lo, this.hi, this.step);

  final int? lo;
  final int? hi;
  final int? step;
}

/// A function made with def.
class _UserFunc {
  _UserFunc(this.def, this.closure, this.defaults);

  final FuncDef def;
  final _Frame? closure; // the frame where the function was defined
  final List<Object?> defaults; // _noDefault when a parameter has none
  _Class? owner; // set for methods
}

/// A function made with lambda.
class _Lambda {
  _Lambda(this.node, this.closure, this.defaults);

  final Lambda node;
  final _Frame? closure;
  final List<Object?> defaults;
}

/// A method that remembers its object (self).
class _BoundMethod {
  _BoundMethod(this.self, this.func);

  final dynamic self;
  final _UserFunc func;
}

/// A class made with the class keyword.
class _Class {
  _Class(this.name, this.base, this.excBase);

  final String name;
  final _Class? base;
  final String? excBase; // name of a built-in exception class (if any)
  final Map<String, _UserFunc> methods = <String, _UserFunc>{};
  final Map<String, dynamic> attrs = <String, dynamic>{};

  _UserFunc? findMethod(String n) {
    _Class? c = this;
    while (c != null) {
      final m = c.methods[n];
      if (m != null) return m;
      c = c.base;
    }
    return null;
  }

  bool hasAttr(String n) {
    _Class? c = this;
    while (c != null) {
      if (c.attrs.containsKey(n)) return true;
      c = c.base;
    }
    return false;
  }

  dynamic getAttr(String n) {
    _Class? c = this;
    while (c != null) {
      if (c.attrs.containsKey(n)) return c.attrs[n];
      c = c.base;
    }
    return null;
  }

  bool isSubclassOf(_Class other) {
    _Class? c = this;
    while (c != null) {
      if (identical(c, other)) return true;
      c = c.base;
    }
    return false;
  }

  String? get exceptionBase {
    _Class? c = this;
    while (c != null) {
      if (c.excBase != null) return c.excBase;
      c = c.base;
    }
    return null;
  }
}

/// An object made from a class.
class _Instance {
  _Instance(this.cls);

  final _Class cls;
  final Map<String, dynamic> fields = <String, dynamic>{};
}

/// A built-in function, type or exception class used as a value.
class _Builtin {
  const _Builtin(this.name);

  final String name;
}

/// An imported module such as math.
class _Module {
  _Module(this.name);

  final String name;
}

/// An exception object such as ValueError("bad").
class _PyExc {
  _PyExc(this.type, this.message);

  final String type;
  final String message;
}

/// The result of type(x).
class _TypeVal {
  _TypeVal(this.name);

  final String name;
}

/// Local variables of one function call (or the main program).
class _Frame {
  _Frame(this.label, {this.parent, this.owner});

  final String label;
  final _Frame? parent; // frame used to look up names that are not local
  final _Class? owner; // class of the method that is running
  dynamic selfValue; // the object for a method
  final Map<String, dynamic> vars = <String, dynamic>{};
  final Set<String> globalNames = <String>{};
  final List<_LoopCtx> loops = <_LoopCtx>[];
}

/// Information about a running loop (shown as a chip).
class _LoopCtx {
  _LoopCtx(this.label, this.total);

  final String label;
  final int total; // 0 when the number of rounds is not known
  int index = 0;
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
  'print', 'len', 'range', 'int', 'float', 'str', 'bool', 'abs', 'min', 'max', //
  'sum', 'list', 'tuple', 'set', 'dict', 'enumerate', 'zip', 'reversed',
  'sorted', 'round', 'pow', 'divmod', 'any', 'all', 'map', 'filter', 'chr',
  'ord', 'type', 'isinstance', 'input', 'repr', 'bin', 'hex', 'oct', 'format',
  'object',
};

const _excNames = {
  'Exception', 'ValueError', 'TypeError', 'ZeroDivisionError', 'IndexError', //
  'KeyError', 'NameError', 'RuntimeError', 'AssertionError', 'AttributeError',
  'OverflowError', 'NotImplementedError', 'ArithmeticError', 'LookupError',
  'StopIteration', 'EOFError',
};

const _mathConstants = {'pi', 'e', 'tau', 'inf', 'nan'};
const _mathFunctions = {
  'sqrt', 'floor', 'ceil', 'pow', 'fabs', 'gcd', 'factorial', 'log', 'log10', //
  'log2', 'exp', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'atan2',
  'radians', 'degrees', 'hypot', 'trunc', 'isqrt',
};

// ================================ the tracer ===============================

/// Runs the user's Python code and records every step.
/// It really executes the code, so the steps are real (not fake).
class PyTracer {
  PyTracer(this.source, {this.inputs = const <String>[]})
      : _lines = source.split('\n');

  final String source;
  final List<String> inputs; // lines for input()
  final List<String> _lines;

  /// Safety limits, so an infinite loop cannot freeze the app.
  static const int maxSteps = 1500;
  static const int maxDepth = 60;

  final List<TraceStep> _steps = <TraceStep>[];
  final List<_Frame> _stack = <_Frame>[];
  final List<String> _out = <String>[];
  String _partial = ''; // text printed with end='' that has no newline yet
  int _inputPos = 0;

  // Array usage in the current statement (for the colors).
  final Map<String, Set<int>> _reads = <String, Set<int>>{};
  final Map<String, Set<int>> _writes = <String, Set<int>>{};
  final Map<String, Set<String>> _dictReads = <String, Set<String>>{};
  final Map<String, Set<String>> _dictWrites = <String, Set<String>>{};
  bool _tracking = true;

  // Source lines of branches that will not run (drawn faded).
  final Set<int> _skipped = <int>{};

  // Information used to draw pointers (i, j, low, mid, high ...).
  final Set<String> _indexVars = <String>{};
  final Map<String, Set<String>> _varArrays = <String, Set<String>>{};
  final List<_IndexSpec> _exprSpecs = <_IndexSpec>[];

  // Small helpers for explanations.
  String? _note;
  String? _lastCompare;
  dynamic _retVal;
  PyError? _activeError; // the error that an except block is handling
  bool _started = false;
  int _curLine = 0;

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
      final type = e.type ?? _guessType(e.message);
      final shown = _started ? '$type: ${e.message}' : 'SyntaxError: ${e.message}';
      error = TraceError(e.line, shown);
      if (_started && e.line != null) {
        try {
          _emit(e.line!, _lineText(e.line!), 'Error: $shown', force: true);
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

  /// The last source line used by a list of statements.
  int _lastLine(List<Stmt> body) {
    var last = 0;
    for (final s in body) {
      var l = s.line;
      if (s is IfStmt) {
        l = math.max(l, math.max(_lastLine(s.body), _lastLine(s.orelse)));
        if (s.elseLine != null) l = math.max(l, s.elseLine!);
      } else if (s is WhileStmt) {
        l = math.max(l, math.max(_lastLine(s.body), _lastLine(s.orelse)));
      } else if (s is ForStmt) {
        l = math.max(l, math.max(_lastLine(s.body), _lastLine(s.orelse)));
      } else if (s is FuncDef) {
        l = math.max(l, _lastLine(s.body));
      } else if (s is ClassDef) {
        l = math.max(l, _lastLine(s.body));
      } else if (s is TryStmt) {
        l = math.max(l, math.max(_lastLine(s.body), _lastLine(s.finalbody)));
        l = math.max(l, _lastLine(s.orelse));
        for (final h in s.handlers) {
          l = math.max(l, math.max(h.line, _lastLine(h.body)));
        }
      }
      if (l > last) last = l;
    }
    return last;
  }

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
      } else if (e is SliceExpr) {
        final parts = <Expr?>[e.lower, e.upper, e.step];
        for (final p in parts) {
          if (p != null) walkExpr(p);
        }
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
        for (final v in e.kwargs.values) {
          walkExpr(v);
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
      } else if (e is SetLit) {
        for (final i in e.items) {
          walkExpr(i);
        }
      } else if (e is DictLit) {
        for (final k in e.keys) {
          walkExpr(k);
        }
        for (final v in e.values) {
          walkExpr(v);
        }
      } else if (e is JoinedStr) {
        for (final p in e.parts) {
          if (p is FStringField) walkExpr(p.expr);
        }
      } else if (e is Lambda) {
        walkExpr(e.body);
      } else if (e is Comp) {
        walkExpr(e.elt);
        final ve = e.valueElt;
        if (ve != null) walkExpr(ve);
        for (final c in e.clauses) {
          walkExpr(c.iter);
          for (final cond in c.conds) {
            walkExpr(cond);
          }
        }
      } else if (e is IfExp) {
        walkExpr(e.test);
        walkExpr(e.body);
        walkExpr(e.orelse);
      }
    }

    // These two local functions call each other recursively.
    // Declare both function variables before assigning either closure,
    // so Dart does not report walkStmt as being used before declaration.
    late void Function(List<Stmt>) walkStmts;
    late void Function(Stmt) walkStmt;

    walkStmts = (List<Stmt> body) {
      for (final s in body) {
        walkStmt(s);
      }
    };

    walkStmt = (Stmt s) {
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
        walkStmts(s.body);
        walkStmts(s.orelse);
      } else if (s is WhileStmt) {
        walkExpr(s.test);
        walkStmts(s.body);
        walkStmts(s.orelse);
      } else if (s is ForStmt) {
        walkExpr(s.iter);
        walkExpr(s.target);
        walkStmts(s.body);
        walkStmts(s.orelse);
      } else if (s is FuncDef) {
        walkStmts(s.body);
      } else if (s is ClassDef) {
        walkStmts(s.body);
      } else if (s is TryStmt) {
        walkStmts(s.body);
        for (final h in s.handlers) {
          walkStmts(h.body);
        }
        walkStmts(s.orelse);
        walkStmts(s.finalbody);
      } else if (s is ReturnStmt) {
        final v = s.value;
        if (v != null) walkExpr(v);
      } else if (s is RaiseStmt) {
        final v = s.exc;
        if (v != null) walkExpr(v);
      } else if (s is AssertStmt) {
        walkExpr(s.test);
      } else if (s is DelStmt) {
        for (final t in s.targets) {
          walkExpr(t);
        }
      }
    };

    walkStmts(program);

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

  // ------------------------------ text of values -----------------------

  String _repr(dynamic v) {
    if (v == null) return 'None';
    if (v is bool) return v ? 'True' : 'False';
    if (v is String) return "'$v'";
    if (v is _Tuple) {
      if (v.length == 1) return '(${_repr(v[0])},)';
      return '(${v.map(_repr).join(', ')})';
    }
    if (v is List) return '[${v.map(_repr).join(', ')}]';
    if (v is Set) {
      if (v.isEmpty) return 'set()';
      return '{${v.map(_repr).join(', ')}}';
    }
    if (v is Map) {
      final parts = <String>[];
      v.forEach((k, val) {
        parts.add('${_repr(k)}: ${_repr(val)}');
      });
      return '{${parts.join(', ')}}';
    }
    if (v is _RangeVal) {
      return v.step == 1
          ? 'range(${v.start}, ${v.stop})'
          : 'range(${v.start}, ${v.stop}, ${v.step})';
    }
    if (v is _Instance) return '<${v.cls.name} object>';
    if (v is _Class) return "<class '${v.name}'>";
    if (v is _UserFunc) return '<function ${v.def.name}>';
    if (v is _BoundMethod) return '<bound method ${v.func.def.name}>';
    if (v is _Lambda) return '<function <lambda>>';
    if (v is _Builtin) return '<built-in ${v.name}>';
    if (v is _Module) return "<module '${v.name}'>";
    if (v is _PyExc) return "${v.type}('${v.message}')";
    if (v is _TypeVal) return "<class '${v.name}'>";
    if (v is double) {
      if (v.isNaN) return 'nan';
      if (v.isInfinite) return v > 0 ? 'inf' : '-inf';
      return v.toString();
    }
    return '$v';
  }

  /// Text used by print() and str().
  String _str(dynamic v) {
    if (v is String) return v;
    if (v is _PyExc) return v.message;
    if (v is _Instance) {
      final m = v.cls.findMethod('__str__');
      if (m != null) {
        final r = _callUser(m, [v], <String, dynamic>{}, _curLine);
        return _str(r);
      }
      if (v.cls.exceptionBase != null) return _excMessage(v);
    }
    return _repr(v);
  }

  String _excMessage(_Instance v) {
    final m = v.fields['message'];
    return m == null ? '' : _str(m);
  }

  List<String> _outLines() =>
      _partial.isEmpty ? List<String>.of(_out) : [..._out, _partial];

  void _writeOut(String text) {
    var buffer = _partial + text;
    var idx = buffer.indexOf('\n');
    while (idx >= 0) {
      _out.add(buffer.substring(0, idx));
      buffer = buffer.substring(idx + 1);
      idx = buffer.indexOf('\n');
    }
    _partial = buffer;
  }

  bool _hiddenValue(dynamic v) =>
      v is _UserFunc || v is _Class || v is _Module || v is _Builtin;

  VarSnapshot _snapshot(String name, dynamic v) {
    if (v is _Instance) {
      return VarSnapshot(
        name: name,
        type: VarType.object,
        text: _repr(v),
        kind: v.cls.name,
        entries: [
          for (final e in v.fields.entries) MapEntry(e.key, _repr(e.value)),
        ],
      );
    }
    if (v is List) {
      final kind = v is _Tuple ? 'tuple' : 'list';
      if (v.isNotEmpty && v.every((e) => e is List)) {
        return VarSnapshot(
          name: name,
          type: VarType.matrix,
          text: _repr(v),
          kind: kind,
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
        kind: kind,
        items: [for (final e in v) _repr(e)],
        numbers: allNumbers ? [for (final e in v) (e as num).toDouble()] : null,
      );
    }
    if (v is Set) {
      final items = v.toList();
      final allNumbers =
          items.isNotEmpty && items.every((e) => e is int || e is double);
      return VarSnapshot(
        name: name,
        type: VarType.list,
        text: _repr(v),
        kind: 'set',
        items: [for (final e in items) _repr(e)],
        numbers:
            allNumbers ? [for (final e in items) (e as num).toDouble()] : null,
      );
    }
    if (v is Map) {
      return VarSnapshot(
        name: name,
        type: VarType.dict,
        text: _repr(v),
        kind: 'dict',
        entries: [
          for (final e in v.entries) MapEntry(_repr(e.key), _repr(e.value)),
        ],
      );
    }
    return VarSnapshot(name: name, type: VarType.scalar, text: _repr(v));
  }

  String _frameLabel(_Frame f) =>
      f.label.length > 40 ? '${f.label.substring(0, 37)}...' : f.label;

  String _loopText(_LoopCtx l) => l.total > 0
      ? '${l.label}: ${l.index} of ${l.total}'
      : '${l.label}: round ${l.index}';

  /// Saves one step.
  void _emit(
    int line,
    String statement,
    String explanation, {
    bool? condition,
    Decision? decision,
    bool force = false,
  }) {
    if (!force && _steps.length >= maxSteps) {
      throw PyError(
        line,
        'Too many steps (more than $maxSteps). Is there an infinite loop?',
        type: 'TimeoutError',
        fatal: true,
      );
    }
    final frame = _stack.last;
    final vars = <String, VarSnapshot>{};
    frame.vars.forEach((k, v) {
      if (_hiddenValue(v)) return;
      vars[k] = _snapshot(k, v);
    });

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
    final dictMarks = <String, Map<String, MarkKind>>{};
    _dictReads.forEach((dict, keys) {
      for (final k in keys) {
        dictMarks.putIfAbsent(dict, () => <String, MarkKind>{})[k] =
            MarkKind.read;
      }
    });
    _dictWrites.forEach((dict, keys) {
      for (final k in keys) {
        dictMarks.putIfAbsent(dict, () => <String, MarkKind>{})[k] =
            MarkKind.write;
      }
    });
    _reads.clear();
    _writes.clear();
    _dictReads.clear();
    _dictWrites.clear();

    _steps.add(TraceStep(
      number: _steps.length + 1,
      line: line,
      statement: statement,
      explanation: explanation,
      vars: vars,
      marks: marks,
      dictMarks: dictMarks,
      pointers: _pointers(frame),
      output: _outLines(),
      callStack: [for (final f in _stack) _frameLabel(f)],
      condition: condition,
      skippedLines: Set<int>.of(_skipped),
      loops: [for (final l in frame.loops) _loopText(l)],
      decision: decision,
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

  List<Object?> _evalDefaults(List<Expr?> defaults) {
    return <Object?>[
      for (final d in defaults) d == null ? _noDefault : _eval(d),
    ];
  }

  Decision _decisionFor(String kind, Expr test, bool result,
      String yesLabel, String noLabel) {
    return Decision(
      kind: kind,
      expression: test.src,
      evaluated: _lastCompare ?? test.src,
      result: result,
      yesLabel: yesLabel,
      noLabel: noLabel,
    );
  }

  _Flow _exec(Stmt s) {
    _note = null;
    _curLine = s.line;
    final text = _lineText(s.line);

    if (s is Assign) {
      final value = _eval(s.value);
      final log = _AssignLog();
      _assign(s.target, value, s.line, log);
      for (final extra in s.extraTargets) {
        _assign(extra, value, s.line, log);
      }
      _emit(s.line, text,
          '${log.allNew ? 'Created' : 'Updated'} ${log.descs.join(', ')}');
      return _Flow.normal;
    }

    if (s is AugAssign) {
      final current = _eval(s.target);
      final rhs = _eval(s.value);
      dynamic result;
      if (s.op == '+' && current is List && current is! _Tuple && rhs is List) {
        current.addAll(rhs); // a list changes in place with +=
        result = current;
      } else {
        result = _binop(s.op, current, rhs, s.line);
      }
      final log = _AssignLog();
      _assign(s.target, result, s.line, log);
      _emit(s.line, text, 'Updated ${log.descs.join(', ')}');
      return _Flow.normal;
    }

    if (s is ExprStmt) {
      final ex = s.expr;
      // A text on its own line (a docstring) does nothing.
      if (ex is Literal && ex.value is String) return _Flow.normal;
      _eval(ex);
      _emit(s.line, text, _note ?? 'Ran ${ex.src}');
      return _Flow.normal;
    }

    if (s is IfStmt) {
      _lastCompare = null;
      final cond = _truthy(_eval(s.test));
      // Lines of the branch that will not run are drawn faded.
      final skip = <int>{};
      if (cond) {
        if (s.orelse.isNotEmpty) {
          final from = s.elseLine ?? s.orelse.first.line;
          for (var l = from; l <= _lastLine(s.orelse); l++) {
            if (l > s.line) skip.add(l);
          }
        }
      } else if (s.body.isNotEmpty) {
        for (var l = s.body.first.line; l <= _lastLine(s.body); l++) {
          if (l > s.line) skip.add(l);
        }
      }
      final before = Set<int>.of(_skipped);
      _skipped.addAll(skip);
      final hasElse = s.orelse.isNotEmpty;
      _emit(
        s.line,
        text,
        '${_lastCompare ?? s.test.src} is ${cond ? 'True, so the block runs' : (hasElse ? 'False, so Python goes to the next branch' : 'False, so the block is skipped')}',
        condition: cond,
        decision: _decisionFor('if', s.test, cond, 'Run the block',
            hasElse ? 'Go to else / elif' : 'Skip the block'),
      );
      _Flow flow = _Flow.normal;
      if (cond) {
        flow = _execBlock(s.body);
      } else if (hasElse) {
        final elseLine = s.elseLine;
        if (elseLine != null) {
          _emit(elseLine, _lineText(elseLine),
              'No condition was True, so the else block runs');
        }
        flow = _execBlock(s.orelse);
      }
      _skipped
        ..clear()
        ..addAll(before);
      return flow;
    }

    if (s is WhileStmt) {
      final frame = _stack.last;
      final ctx = _LoopCtx('while', 0);
      frame.loops.add(ctx);
      var broke = false;
      while (true) {
        _lastCompare = null;
        final cond = _truthy(_eval(s.test));
        ctx.index++;
        _emit(
          s.line,
          text,
          '${_lastCompare ?? s.test.src} is ${cond ? 'True, so the loop body runs' : 'False, so the loop stops'}',
          condition: cond,
          decision: _decisionFor(
              'while', s.test, cond, 'Run the loop body', 'Leave the loop'),
        );
        if (!cond) break;
        final flow = _execBlock(s.body);
        if (flow == _Flow.brk) {
          broke = true;
          break;
        }
        if (flow == _Flow.ret) {
          frame.loops.remove(ctx);
          return flow;
        }
      }
      frame.loops.remove(ctx);
      if (!broke && s.orelse.isNotEmpty) {
        final el = s.elseLine;
        if (el != null) {
          _emit(el, _lineText(el), 'The loop ended without break, so else runs');
        }
        return _execBlock(s.orelse);
      }
      return _Flow.normal;
    }

    if (s is ForStmt) {
      final iterRaw = _eval(s.iter);
      // A dictionary or a set is looped as a list of its items.
      final it = iterRaw is Map
          ? iterRaw.keys.toList()
          : (iterRaw is Set ? iterRaw.toList() : iterRaw);
      if (it is! List && it is! String && it is! _RangeVal) {
        throw PyError(s.line, "'${_typeName(it)}' object is not iterable",
            type: 'TypeError');
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

      final frame = _stack.last;
      final ctx = _LoopCtx('for ${s.target.src}', lengthNow());
      frame.loops.add(ctx);
      var broke = false;
      for (var idx = 0; idx < lengthNow(); idx++) {
        ctx.index = idx + 1;
        final log = _AssignLog();
        _assign(s.target, itemAt(idx), s.line, log);
        _emit(s.line, text, 'Iteration ${idx + 1}: ${log.descs.join(', ')}');
        final flow = _execBlock(s.body);
        if (flow == _Flow.brk) {
          broke = true;
          break;
        }
        if (flow == _Flow.ret) {
          frame.loops.remove(ctx);
          return flow;
        }
      }
      frame.loops.remove(ctx);
      if (!broke) {
        _emit(s.line, text, 'No more items, so the for loop ends');
        if (s.orelse.isNotEmpty) {
          final el = s.elseLine;
          if (el != null) {
            _emit(el, _lineText(el), 'The loop ended without break, so else runs');
          }
          return _execBlock(s.orelse);
        }
      }
      return _Flow.normal;
    }

    if (s is FuncDef) {
      if (s.decorators.isNotEmpty) {
        throw PyError(s.line,
            'Decorators are only supported on methods inside a class',
            type: 'NotImplementedError');
      }
      final f = _UserFunc(s, _stack.last, _evalDefaults(s.defaults));
      _stack.last.vars[s.name] = f;
      _emit(s.line, text,
          'Function ${s.name}(${s.params.join(', ')}) is defined. It runs only when it is called.');
      return _Flow.normal;
    }

    if (s is ClassDef) {
      if (s.bases.length > 1) {
        throw PyError(s.line, 'Multiple inheritance is not supported yet',
            type: 'NotImplementedError');
      }
      _Class? base;
      String? excBase;
      if (s.bases.isNotEmpty) {
        final b = _eval(s.bases.first);
        if (b is _Class) {
          base = b;
        } else if (b is _Builtin && _excNames.contains(b.name)) {
          excBase = b.name;
        } else if (b is _Builtin && b.name == 'object') {
          base = null;
        } else {
          throw PyError(s.line, 'This base class is not supported',
              type: 'TypeError');
        }
      }
      final cls = _Class(s.name, base, excBase);
      for (final st in s.body) {
        if (st is FuncDef) {
          for (final d in st.decorators) {
            if (d != 'staticmethod' && d != 'classmethod' && d != 'property') {
              throw PyError(
                  st.line,
                  d.endsWith('.setter')
                      ? 'Property setters are not supported yet'
                      : 'The decorator @$d is not supported yet',
                  type: 'NotImplementedError');
            }
          }
          final f = _UserFunc(st, _stack.last, _evalDefaults(st.defaults));
          f.owner = cls;
          cls.methods[st.name] = f;
        } else if (st is Assign &&
            st.target is Name &&
            st.extraTargets.isEmpty) {
          cls.attrs[(st.target as Name).id] = _eval(st.value);
        } else if (st is PassStmt) {
          // nothing to do
        } else if (st is ExprStmt && st.expr is Literal) {
          // a docstring
        } else {
          throw PyError(st.line,
              'Only methods and simple attributes are supported inside a class',
              type: 'NotImplementedError');
        }
      }
      _stack.last.vars[s.name] = cls;
      _emit(s.line, text,
          'Class ${s.name} is defined with ${cls.methods.length} method(s). Objects are made by calling ${s.name}().');
      return _Flow.normal;
    }

    if (s is ReturnStmt) {
      if (_stack.length <= 1) {
        throw PyError(s.line, "'return' is only allowed inside a function",
            type: 'SyntaxError');
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

    if (s is GlobalStmt) {
      _stack.last.globalNames.addAll(s.names);
      _emit(s.line, text,
          'global ${s.names.join(', ')}: changes to these names change the global variables');
      return _Flow.normal;
    }

    if (s is ImportStmt) {
      for (final item in s.items) {
        final mod = _importModule(item[0], s.line);
        final alias = item[1].isEmpty ? item[0] : item[1];
        _stack.last.vars[alias] = mod;
      }
      _emit(s.line, text,
          'Imported ${s.items.map((e) => e[0]).join(', ')}');
      return _Flow.normal;
    }

    if (s is FromImportStmt) {
      final mod = _importModule(s.module, s.line);
      for (final item in s.items) {
        final alias = item[1].isEmpty ? item[0] : item[1];
        _stack.last.vars[alias] = _moduleMember(mod, item[0], s.line);
      }
      _emit(s.line, text,
          'Imported ${s.items.map((e) => e[0]).join(', ')} from ${s.module}');
      return _Flow.normal;
    }

    if (s is DelStmt) {
      final done = <String>[];
      for (final t in s.targets) {
        if (t is Name) {
          if (!_stack.last.vars.containsKey(t.id)) {
            throw PyError(s.line, "Name '${t.id}' is not defined",
                type: 'NameError');
          }
          _stack.last.vars.remove(t.id);
          done.add(t.id);
        } else if (t is Subscript) {
          final container = _eval(t.target);
          final idx = _eval(t.index);
          if (container is Map) {
            if (!container.containsKey(idx)) {
              throw PyError(s.line, 'Key ${_repr(idx)} is not in the dictionary',
                  type: 'KeyError');
            }
            container.remove(idx);
            done.add('${t.target.src}[${_repr(idx)}]');
          } else if (container is List && container is! _Tuple && idx is int) {
            final norm = _normIndex(idx, container.length, s.line);
            container.removeAt(norm);
            done.add('${t.target.src}[$norm]');
          } else {
            throw PyError(s.line, 'Cannot delete this item', type: 'TypeError');
          }
        } else {
          throw PyError(s.line, 'Cannot delete this expression',
              type: 'SyntaxError');
        }
      }
      _emit(s.line, text, 'Deleted ${done.join(', ')}');
      return _Flow.normal;
    }

    if (s is AssertStmt) {
      _lastCompare = null;
      final ok = _truthy(_eval(s.test));
      _emit(
        s.line,
        text,
        '${_lastCompare ?? s.test.src} is ${ok ? 'True, so the program continues' : 'False, so AssertionError is raised'}',
        condition: ok,
        decision: _decisionFor(
            'assert', s.test, ok, 'Continue', 'Raise AssertionError'),
      );
      if (!ok) {
        final m = s.msg;
        final msg = m == null ? '' : _str(_eval(m));
        throw PyError(s.line, msg.isEmpty ? 'Assertion failed' : msg,
            type: 'AssertionError');
      }
      return _Flow.normal;
    }

    if (s is RaiseStmt) {
      final ex = s.exc;
      if (ex == null) {
        final active = _activeError;
        if (active == null) {
          throw PyError(s.line, 'There is no active exception to re-raise',
              type: 'RuntimeError');
        }
        _emit(s.line, text, 'Raise the same error again');
        throw active;
      }
      var v = _eval(ex);
      if (v is _Builtin && _excNames.contains(v.name)) {
        v = _PyExc(v.name, '');
      }
      if (v is _Class) {
        v = _instantiate(v, <dynamic>[], <String, dynamic>{}, s.line);
      }
      if (v is _PyExc) {
        _emit(s.line, text, 'Raise ${v.type}: ${v.message}');
        throw PyError(s.line, v.message, type: v.type, value: v);
      }
      if (v is _Instance && v.cls.exceptionBase != null) {
        final msg = _excMessage(v);
        _emit(s.line, text, 'Raise ${v.cls.name}: $msg');
        throw PyError(s.line, msg, type: v.cls.name, value: v);
      }
      throw PyError(s.line, 'Only exceptions can be raised',
          type: 'TypeError');
    }

    if (s is TryStmt) {
      return _execTry(s, text);
    }

    throw PyError(s.line, 'This statement is not supported yet',
        type: 'NotImplementedError');
  }

  // --------------------------- try / except ---------------------------

  _Flow _execTry(TryStmt s, String text) {
    _emit(s.line, text,
        'try: run the block. If an error happens, Python looks for a matching except.');
    var flow = _Flow.normal;
    PyError? pending;
    var bodyOk = false;
    final depth = _stack.length;
    final frame = _stack.last;
    final loopCount = frame.loops.length;
    final skipSave = Set<int>.of(_skipped);

    try {
      flow = _execBlock(s.body);
      bodyOk = true;
    } on PyError catch (e) {
      if (e.fatal) rethrow;
      // Remove the frames of calls that were interrupted by the error.
      while (_stack.length > depth) {
        _stack.removeLast();
      }
      while (frame.loops.length > loopCount) {
        frame.loops.removeLast();
      }
      _skipped
        ..clear()
        ..addAll(skipSave);
      ExceptHandler? handler;
      for (final h in s.handlers) {
        if (_handlerMatches(h.type, e)) {
          handler = h;
          break;
        }
      }
      if (handler == null) {
        pending = e;
      } else {
        final type = e.type ?? _guessType(e.message);
        if (handler.name != null) {
          frame.vars[handler.name!] = e.value ?? _PyExc(type, e.message);
        }
        _emit(handler.line, _lineText(handler.line),
            '$type caught: ${e.message}. The except block runs.');
        final savedActive = _activeError;
        _activeError = e;
        try {
          flow = _execBlock(handler.body);
        } on PyError catch (e2) {
          pending = e2;
        }
        _activeError = savedActive;
      }
    }

    if (bodyOk && pending == null && flow == _Flow.normal && s.orelse.isNotEmpty) {
      final el = s.elseLine;
      if (el != null) {
        _emit(el, _lineText(el), 'No error happened, so the else block runs');
      }
      try {
        flow = _execBlock(s.orelse);
      } on PyError catch (e3) {
        pending = e3;
      }
    }

    if (s.finalbody.isNotEmpty) {
      final fl = s.finallyLine;
      if (fl != null) {
        _emit(fl, _lineText(fl), 'finally: this block always runs');
      }
      final savedRet = _retVal;
      final f2 = _execBlock(s.finalbody);
      if (f2 == _Flow.normal) _retVal = savedRet;
      if (f2 != _Flow.normal) {
        flow = f2;
        pending = null;
      }
    }
    if (pending != null) throw pending;
    return flow;
  }

  bool _handlerMatches(Expr? typeExpr, PyError e) {
    if (typeExpr == null) return true;
    final tv = _eval(typeExpr);
    final candidates = tv is List ? tv : <dynamic>[tv];
    final actual = e.type ?? _guessType(e.message);
    for (final c in candidates) {
      if (c is _Builtin) {
        if (_excMatches(actual, c.name)) return true;
        final v = e.value;
        if (v is _Instance && _instMatchesBuiltin(v, c.name)) return true;
      } else if (c is _Class) {
        final v = e.value;
        if (v is _Instance && v.cls.isSubclassOf(c)) return true;
      }
    }
    return false;
  }

  bool _excMatches(String actual, String handler) {
    if (handler == actual || handler == 'Exception') return true;
    if (handler == 'ArithmeticError' &&
        (actual == 'ZeroDivisionError' || actual == 'OverflowError')) {
      return true;
    }
    if (handler == 'LookupError' &&
        (actual == 'IndexError' || actual == 'KeyError')) {
      return true;
    }
    return false;
  }

  bool _instMatchesBuiltin(_Instance v, String name) {
    final base = v.cls.exceptionBase;
    if (base == null) return false;
    return name == 'Exception' || base == name;
  }

  String _guessType(String m) {
    if (m.contains('Division by zero') || m.contains('Modulo by zero')) {
      return 'ZeroDivisionError';
    }
    if (m.contains('out of range')) return 'IndexError';
    if (m.contains('is not in the dictionary')) return 'KeyError';
    if (m.contains('is not defined')) return 'NameError';
    if (m.contains('Cannot convert') || m.contains('invalid literal')) {
      return 'ValueError';
    }
    if (m.contains('has no attribute') || m.contains('has no method')) {
      return 'AttributeError';
    }
    if (m.contains('Assertion')) return 'AssertionError';
    if (m.contains('Cannot use') ||
        m.contains('not supported between') ||
        m.contains('not iterable') ||
        m.contains('cannot be indexed') ||
        m.contains('not callable') ||
        m.contains('does not support item assignment') ||
        m.contains('needs ')) {
      return 'TypeError';
    }
    return 'RuntimeError';
  }

  // ----------------------------- assignment ----------------------------

  void _assign(Expr target, dynamic value, int line, _AssignLog log) {
    if (target is Name) {
      final cur = _stack.last;
      final frame = cur.globalNames.contains(target.id) ? _stack.first : cur;
      if (frame.vars.containsKey(target.id)) log.allNew = false;
      frame.vars[target.id] = value;
      log.descs.add('${target.id} = ${_repr(value)}');
      return;
    }

    if (target is Attribute) {
      final obj = _eval(target.obj);
      if (obj is _Instance) {
        if (obj.fields.containsKey(target.name)) log.allNew = false;
        obj.fields[target.name] = value;
        log.descs.add('${target.src} = ${_repr(value)}');
        return;
      }
      if (obj is _Class) {
        obj.attrs[target.name] = value;
        log.allNew = false;
        log.descs.add('${target.src} = ${_repr(value)}');
        return;
      }
      throw PyError(line, "Cannot set an attribute on a ${_typeName(obj)}",
          type: 'AttributeError');
    }

    if (target is Subscript) {
      final container = _eval(target.target);
      final idx = _eval(target.index);
      if (idx is _SliceVal) {
        throw PyError(line, 'Slice assignment is not supported yet',
            type: 'NotImplementedError');
      }
      if (container is Map) {
        _checkKey(idx, line);
        if (container.containsKey(idx)) log.allNew = false;
        container[idx] = value;
        final dictBase = target.target;
        if (dictBase is Name && _tracking) {
          _dictWrites
              .putIfAbsent(dictBase.id, () => <String>{})
              .add(_repr(idx));
        }
        log.descs.add('${target.target.src}[${_repr(idx)}] = ${_repr(value)}');
        return;
      }
      if (container is _Tuple) {
        throw PyError(line, "'tuple' object does not support item assignment",
            type: 'TypeError');
      }
      if (container is! List) {
        throw PyError(line,
            "'${_typeName(container)}' object does not support item assignment",
            type: 'TypeError');
      }
      if (idx is! int) {
        throw PyError(line, 'List index must be an integer', type: 'TypeError');
      }
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
      List<dynamic> values;
      if (value is List) {
        values = value;
      } else if (value is String) {
        values = value.split('');
      } else {
        throw PyError(line, 'Cannot unpack a ${_typeName(value)} value',
            type: 'TypeError');
      }
      if (values.length != target.items.length) {
        throw PyError(line,
            'Cannot unpack ${values.length} values into ${target.items.length} names',
            type: 'ValueError');
      }
      final copy = List<dynamic>.of(values);
      for (var i = 0; i < target.items.length; i++) {
        _assign(target.items[i], copy[i], line, log);
      }
      return;
    }

    throw PyError(line, 'Cannot assign to this expression',
        type: 'SyntaxError');
  }

  int _normIndex(int idx, int length, int line) {
    final norm = idx < 0 ? idx + length : idx;
    if (norm < 0 || norm >= length) {
      throw PyError(line, 'Index $idx is out of range (length is $length)',
          type: 'IndexError');
    }
    return norm;
  }

  // ------------------------------ modules ------------------------------

  _Module _importModule(String name, int line) {
    if (name == 'math') return _Module('math');
    throw PyError(
        line, "Module '$name' is not supported yet. Available module: math.",
        type: 'ImportError');
  }

  dynamic _moduleMember(_Module m, String name, int line) {
    if (m.name == 'math') {
      if (_mathConstants.contains(name)) {
        switch (name) {
          case 'pi':
            return math.pi;
          case 'e':
            return math.e;
          case 'tau':
            return 2 * math.pi;
          case 'inf':
            return double.infinity;
          default:
            return double.nan;
        }
      }
      if (_mathFunctions.contains(name)) return _Builtin('math.$name');
    }
    throw PyError(line, "Module '${m.name}' has no attribute '$name'",
        type: 'AttributeError');
  }

  // ---------------------------- expressions ----------------------------

  dynamic _lookup(String id, int line) {
    _Frame? f = _stack.last;
    while (f != null) {
      if (f.vars.containsKey(id)) return f.vars[id];
      f = f.parent;
    }
    final root = _stack.first;
    if (root.vars.containsKey(id)) return root.vars[id];
    if (_builtinNames.contains(id) || _excNames.contains(id)) {
      return _Builtin(id);
    }
    throw PyError(line, "Name '$id' is not defined", type: 'NameError');
  }

  dynamic _eval(Expr e) {
    if (e is Literal) return e.value;
    if (e is Name) return _lookup(e.id, e.line);

    if (e is JoinedStr) return _evalFString(e);

    if (e is ListLit) return <dynamic>[for (final i in e.items) _eval(i)];
    if (e is TupleLit) return _Tuple(<dynamic>[for (final i in e.items) _eval(i)]);

    if (e is SetLit) {
      final set = <dynamic>{};
      for (final i in e.items) {
        final v = _eval(i);
        _checkKey(v, e.line);
        set.add(v);
      }
      return set;
    }

    if (e is DictLit) {
      final map = <dynamic, dynamic>{};
      for (var i = 0; i < e.keys.length; i++) {
        final k = _eval(e.keys[i]);
        _checkKey(k, e.line);
        map[k] = _eval(e.values[i]);
      }
      return map;
    }

    if (e is Lambda) {
      return _Lambda(e, _stack.last, _evalDefaults(e.defaults));
    }

    if (e is Comp) return _evalComp(e);

    if (e is SliceExpr) {
      int? part(Expr? x) {
        if (x == null) return null;
        final v = _eval(x);
        if (v is int) return v;
        if (v == null) return null;
        throw PyError(e.line, 'Slice indexes must be whole numbers',
            type: 'TypeError');
      }

      return _SliceVal(part(e.lower), part(e.upper), part(e.step));
    }

    if (e is UnaryOp) {
      final v = _eval(e.operand);
      if (e.op == 'not') return !_truthy(v);
      final n = v is bool ? (v ? 1 : 0) : v;
      if (n is! num) {
        throw PyError(e.line, 'Bad operand type for unary ${e.op}',
            type: 'TypeError');
      }
      if (e.op == '~') {
        if (n is! int) {
          throw PyError(e.line, 'Bad operand type for unary ~',
              type: 'TypeError');
        }
        return ~n;
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
          _lastCompare = '${_repr(left)} ${e.ops[i]} ${_repr(right)}';
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
      if (container is Map) {
        if (!container.containsKey(idx)) {
          throw PyError(e.line, 'Key ${_repr(idx)} is not in the dictionary',
              type: 'KeyError');
        }
        final dictBase = e.target;
        if (_tracking && dictBase is Name) {
          _dictReads
              .putIfAbsent(dictBase.id, () => <String>{})
              .add(_repr(idx));
        }
        return container[idx];
      }
      if (idx is _SliceVal) return _sliceValue(container, idx, e.line);
      if (idx is! int) {
        throw PyError(e.line, 'Index must be a whole number', type: 'TypeError');
      }
      int length;
      if (container is List) {
        length = container.length;
      } else if (container is String) {
        length = container.length;
      } else {
        throw PyError(
            e.line, "'${_typeName(container)}' object cannot be indexed",
            type: 'TypeError');
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
      return _getAttr(_eval(e.obj), e.name, e.line);
    }

    throw PyError(e.line, 'This expression is not supported yet',
        type: 'NotImplementedError');
  }

  // ------------------------------ f-strings ----------------------------

  String _evalFString(JoinedStr e) {
    final b = StringBuffer();
    for (final p in e.parts) {
      if (p is String) {
        b.write(p);
      } else if (p is FStringField) {
        final v = _eval(p.expr);
        if (p.conv == 'r' || p.conv == 'a') {
          b.write(_formatValue(_repr(v), p.spec, e.line));
        } else if (p.conv == 's') {
          b.write(_formatValue(_str(v), p.spec, e.line));
        } else {
          b.write(_formatValue(v, p.spec, e.line));
        }
      }
    }
    return b.toString();
  }

  String _groupDigits(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return b.toString();
  }

  /// Formats a value with a format spec such as ".2f", ">10" or "05d".
  String _formatValue(dynamic v, String spec, int line) {
    if (spec.isEmpty) return _str(v);
    final m = RegExp(
      r'^(?:(.)?([<>^=]))?([+\- ])?(#)?(0)?(\d+)?(,)?(?:\.(\d+))?([bcdeEfFgGnosxX%])?$',
    ).firstMatch(spec);
    if (m == null) {
      throw PyError(line, "Unsupported format spec '$spec'", type: 'ValueError');
    }
    var fill = m.group(1) ?? ' ';
    var align = m.group(2);
    final sign = m.group(3);
    final alt = m.group(4) != null;
    final zero = m.group(5) != null;
    final width = int.tryParse(m.group(6) ?? '') ?? 0;
    final comma = m.group(7) != null;
    final prec = m.group(8) == null ? null : int.parse(m.group(8)!);
    final type = m.group(9);

    final isNumber = v is num || v is bool;
    final num? nv = v is bool ? (v ? 1 : 0) : (v is num ? v : null);
    String body;
    var negative = false;

    if (type == 'c') {
      if (nv is! int) {
        throw PyError(line, "format 'c' needs a whole number", type: 'ValueError');
      }
      body = String.fromCharCode(nv);
    } else if (type == 'd' || type == 'x' || type == 'X' || type == 'o' || type == 'b' || type == 'n') {
      if (nv is! int) {
        throw PyError(line, "format '$type' needs a whole number",
            type: 'ValueError');
      }
      negative = nv < 0;
      final a = nv.abs();
      switch (type) {
        case 'x':
          body = (alt ? '0x' : '') + a.toRadixString(16);
          break;
        case 'X':
          body = (alt ? '0X' : '') + a.toRadixString(16).toUpperCase();
          break;
        case 'o':
          body = (alt ? '0o' : '') + a.toRadixString(8);
          break;
        case 'b':
          body = (alt ? '0b' : '') + a.toRadixString(2);
          break;
        default:
          body = comma ? _groupDigits(a.toString()) : a.toString();
      }
    } else if (type == 'f' || type == 'F' || type == '%' || type == 'e' || type == 'E' || type == 'g' || type == 'G') {
      if (nv == null) {
        throw PyError(line, "format '$type' needs a number", type: 'ValueError');
      }
      var x = nv.toDouble();
      if (type == '%') x *= 100;
      negative = x < 0;
      final a = x.abs();
      if (type == 'e' || type == 'E') {
        var s = a.toStringAsExponential(prec ?? 6);
        s = s.replaceFirstMapped(RegExp(r'e([+-])(\d)$'), (mm) => 'e${mm[1]}0${mm[2]}');
        body = type == 'E' ? s.toUpperCase() : s;
      } else if (type == 'g' || type == 'G') {
        body = _str(a);
      } else {
        final s = a.toStringAsFixed(prec ?? 6);
        if (comma) {
          final dot = s.indexOf('.');
          body = dot < 0
              ? _groupDigits(s)
              : _groupDigits(s.substring(0, dot)) + s.substring(dot);
        } else {
          body = s;
        }
        if (type == '%') body = '$body%';
      }
    } else if (type == 's' || type == null) {
      if (isNumber && type == null) {
        if (nv is int) {
          negative = nv < 0;
          final a = nv.abs();
          body = comma ? _groupDigits(a.toString()) : a.toString();
        } else {
          final d = nv!.toDouble();
          negative = d < 0;
          body = prec != null ? d.abs().toStringAsPrecision(prec) : _str(d.abs());
        }
      } else {
        var s = _str(v);
        if (prec != null && prec < s.length) s = s.substring(0, prec);
        body = s;
      }
    } else {
      body = _str(v);
    }

    var signText = '';
    if (negative) {
      signText = '-';
    } else if (isNumber && sign == '+') {
      signText = '+';
    } else if (isNumber && sign == ' ') {
      signText = ' ';
    }

    if (zero && align == null && isNumber) {
      fill = '0';
      align = '=';
    }
    align ??= isNumber ? '>' : '<';

    final total = signText.length + body.length;
    if (width <= total) return signText + body;
    final pad = width - total;
    switch (align) {
      case '<':
        return signText + body + fill * pad;
      case '^':
        final left = pad ~/ 2;
        return fill * left + signText + body + fill * (pad - left);
      case '=':
        return signText + fill * pad + body;
      default:
        return fill * pad + signText + body;
    }
  }

  /// str.format: "{} is {:.2f}".format(a, b)
  String _strFormat(String tpl, List<dynamic> args, Map<String, dynamic> kwargs, int line) {
    final b = StringBuffer();
    var auto = 0;
    var i = 0;
    while (i < tpl.length) {
      final c = tpl[i];
      if (c == '{') {
        if (i + 1 < tpl.length && tpl[i + 1] == '{') {
          b.write('{');
          i += 2;
          continue;
        }
        final end = tpl.indexOf('}', i);
        if (end < 0) {
          throw PyError(line, "Single '{' in the format string", type: 'ValueError');
        }
        var field = tpl.substring(i + 1, end);
        var spec = '';
        final colon = field.indexOf(':');
        if (colon >= 0) {
          spec = field.substring(colon + 1);
          field = field.substring(0, colon);
        }
        var conv = '';
        final bang = field.indexOf('!');
        if (bang >= 0) {
          conv = field.substring(bang + 1);
          field = field.substring(0, bang);
        }
        dynamic value;
        if (field.isEmpty) {
          if (auto >= args.length) {
            throw PyError(line, 'Not enough arguments for format()', type: 'IndexError');
          }
          value = args[auto++];
        } else if (int.tryParse(field) != null) {
          final k = int.parse(field);
          if (k >= args.length) {
            throw PyError(line, 'Not enough arguments for format()', type: 'IndexError');
          }
          value = args[k];
        } else {
          if (!kwargs.containsKey(field)) {
            throw PyError(line, "No value for '$field' in format()", type: 'KeyError');
          }
          value = kwargs[field];
        }
        if (conv == 'r') value = _repr(value);
        b.write(_formatValue(value, spec, line));
        i = end + 1;
        continue;
      }
      if (c == '}') {
        if (i + 1 < tpl.length && tpl[i + 1] == '}') {
          b.write('}');
          i += 2;
          continue;
        }
        throw PyError(line, "Single '}' in the format string", type: 'ValueError');
      }
      b.write(c);
      i++;
    }
    return b.toString();
  }

  // --------------------------- comprehensions --------------------------

  dynamic _evalComp(Comp c) {
    final frame = _Frame(
      c.kind == 'dict' ? '<dict comprehension>' : '<comprehension>',
      parent: _stack.last,
    );
    _stack.add(frame);
    final listOut = <dynamic>[];
    final mapOut = <dynamic, dynamic>{};

    void run(int ci) {
      if (ci == c.clauses.length) {
        if (c.kind == 'dict') {
          final k = _eval(c.elt);
          _checkKey(k, c.line);
          mapOut[k] = _eval(c.valueElt!);
        } else {
          listOut.add(_eval(c.elt));
        }
        return;
      }
      final cl = c.clauses[ci];
      final items = _toList(_eval(cl.iter), c.line);
      for (final item in items) {
        _assign(cl.target, item, c.line, _AssignLog());
        var ok = true;
        for (final cond in cl.conds) {
          if (!_truthy(_eval(cond))) {
            ok = false;
            break;
          }
        }
        if (ok) run(ci + 1);
      }
    }

    run(0);
    _stack.removeLast();
    if (c.kind == 'dict') return mapOut;
    if (c.kind == 'set') {
      final s = <dynamic>{};
      for (final x in listOut) {
        _checkKey(x, c.line);
        s.add(x);
      }
      return s;
    }
    return listOut;
  }

  // ------------------------------ slicing ------------------------------

  dynamic _sliceValue(dynamic c, _SliceVal s, int line) {
    int length;
    if (c is List) {
      length = c.length;
    } else if (c is String) {
      length = c.length;
    } else {
      throw PyError(line, "'${_typeName(c)}' object cannot be sliced",
          type: 'TypeError');
    }
    final step = s.step ?? 1;
    if (step == 0) {
      throw PyError(line, 'Slice step cannot be zero', type: 'ValueError');
    }
    final lower = step > 0 ? 0 : -1;
    final upper = step > 0 ? length : length - 1;
    int clampIndex(int? v, int dflt) {
      if (v == null) return dflt;
      if (v < 0) return math.max(v + length, lower);
      return math.min(v, upper);
    }

    final start = clampIndex(s.lo, step > 0 ? lower : upper);
    final stop = clampIndex(s.hi, step > 0 ? upper : lower);
    final picked = <int>[];
    if (step > 0) {
      for (var i = start; i < stop; i += step) {
        picked.add(i);
      }
    } else {
      for (var i = start; i > stop; i += step) {
        picked.add(i);
      }
    }
    if (c is String) return picked.map((i) => c[i]).join();
    final items = <dynamic>[for (final i in picked) (c as List)[i]];
    return c is _Tuple ? _Tuple(items) : items;
  }

  // -------------------------- basic operations -------------------------

  // Dictionary keys and set items must be simple values.
  void _checkKey(dynamic k, int line) {
    if ((k is List && k is! _Tuple) || k is Map || k is Set) {
      throw PyError(line, "A ${_typeName(k)} cannot be used as a dictionary key or set item",
          type: 'TypeError');
    }
  }

  bool _truthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty;
    if (v is List) return v.isNotEmpty;
    if (v is Map) return v.isNotEmpty;
    if (v is Set) return v.isNotEmpty;
    if (v is _RangeVal) return v.length > 0;
    return true;
  }

  String _typeName(dynamic v) {
    if (v == null) return 'NoneType';
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'float';
    if (v is String) return 'str';
    if (v is _Tuple) return 'tuple';
    if (v is List) return 'list';
    if (v is Map) return 'dict';
    if (v is Set) return 'set';
    if (v is _RangeVal) return 'range';
    if (v is _Instance) return v.cls.name;
    if (v is _PyExc) return v.type;
    if (v is _UserFunc || v is _Lambda || v is _BoundMethod) return 'function';
    if (v is _Class) return 'type';
    if (v is _Module) return 'module';
    if (v is _Builtin) return 'builtin_function_or_method';
    return 'object';
  }

  num _checkNum(num v, int line) {
    if (v is int && v.abs() > _maxInt) {
      throw PyError(line,
          'Number is too big for this visualizer (limit is $_maxInt)',
          type: 'OverflowError');
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
          if (y == 0) {
            throw PyError(line, 'Division by zero', type: 'ZeroDivisionError');
          }
          return x / y;
        case '//':
          if (y == 0) {
            throw PyError(line, 'Division by zero', type: 'ZeroDivisionError');
          }
          if (x is int && y is int) return _floorDiv(x, y);
          return (x / y).floorToDouble();
        case '%':
          if (y == 0) {
            throw PyError(line, 'Modulo by zero', type: 'ZeroDivisionError');
          }
          if (x is int && y is int) return _mod(x, y);
          return x - y * (x / y).floorToDouble();
        case '**':
          if (x is int && y is int && y >= 0) {
            if (y > 10000) {
              throw PyError(line, 'Exponent is too large', type: 'OverflowError');
            }
            num result = 1;
            for (var i = 0; i < y; i++) {
              result = _checkNum(result * x, line);
            }
            return result;
          }
          return math.pow(x, y);
        case '&':
          if (x is int && y is int) return x & y;
          break;
        case '|':
          if (x is int && y is int) return x | y;
          break;
        case '^':
          if (x is int && y is int) return x ^ y;
          break;
        case '<<':
          if (x is int && y is int) {
            if (y < 0) {
              throw PyError(line, 'Negative shift count', type: 'ValueError');
            }
            if (y > 52) {
              throw PyError(line, 'Shift is too large for this visualizer',
                  type: 'OverflowError');
            }
            return _checkNum(x * math.pow(2, y).toInt(), line);
          }
          break;
        case '>>':
          if (x is int && y is int) {
            if (y < 0) {
              throw PyError(line, 'Negative shift count', type: 'ValueError');
            }
            return y > 62 ? (x < 0 ? -1 : 0) : (x >> y);
          }
          break;
      }
    }

    // Sets.
    if (a is Set && b is Set) {
      if (op == '|') return <dynamic>{...a, ...b};
      if (op == '&') return <dynamic>{for (final v in a) if (b.contains(v)) v};
      if (op == '-') return <dynamic>{for (final v in a) if (!b.contains(v)) v};
      if (op == '^') {
        return <dynamic>{
          for (final v in a) if (!b.contains(v)) v,
          for (final v in b) if (!a.contains(v)) v,
        };
      }
    }

    // Text, lists and tuples.
    if (op == '+') {
      if (a is String && b is String) return a + b;
      if (a is _Tuple && b is _Tuple) return _Tuple(<dynamic>[...a, ...b]);
      if (a is List && b is List && a is! _Tuple && b is! _Tuple) {
        return <dynamic>[...a, ...b];
      }
    }
    if (op == '*') {
      if (a is String && y is int) return y <= 0 ? '' : a * y;
      if (x is int && b is String) return x <= 0 ? '' : b * x;
      if (a is List && y is int) {
        final items = <dynamic>[for (var i = 0; i < y; i++) ...a];
        return a is _Tuple ? _Tuple(items) : items;
      }
      if (x is int && b is List) {
        final items = <dynamic>[for (var i = 0; i < x; i++) ...b];
        return b is _Tuple ? _Tuple(items) : items;
      }
    }
    if (op == '%' && a is String) {
      throw PyError(line, "The % text format is not supported yet. Use an f-string.",
          type: 'NotImplementedError');
    }
    throw PyError(line,
        "Cannot use '$op' with ${_typeName(a)} and ${_typeName(b)}",
        type: 'TypeError');
  }

  bool _eq(dynamic a, dynamic b) {
    final x = a is bool ? (a ? 1 : 0) : a;
    final y = b is bool ? (b ? 1 : 0) : b;
    if (x is num && y is num) return x == y;
    if (x is List && y is List) {
      if ((x is _Tuple) != (y is _Tuple)) return false;
      if (x.length != y.length) return false;
      for (var i = 0; i < x.length; i++) {
        if (!_eq(x[i], y[i])) return false;
      }
      return true;
    }
    if (x is Map && y is Map) {
      if (x.length != y.length) return false;
      for (final k in x.keys) {
        if (!y.containsKey(k) || !_eq(x[k], y[k])) return false;
      }
      return true;
    }
    if (x is Set && y is Set) {
      return x.length == y.length && x.every((v) => y.contains(v));
    }
    if (x is _TypeVal && y is _TypeVal) return x.name == y.name;
    if (x is _Instance || y is _Instance) return identical(x, y);
    return x == y;
  }

  bool _contains(dynamic container, dynamic item, int line) {
    if (container is List) return container.any((e) => _eq(e, item));
    if (container is String) {
      if (item is! String) {
        throw PyError(line, "'in <string>' needs a string on the left",
            type: 'TypeError');
      }
      return container.contains(item);
    }
    if (container is Map) return container.containsKey(item);
    if (container is Set) return container.contains(item);
    if (container is _RangeVal) {
      for (var i = 0; i < container.length; i++) {
        if (container.at(i) == item) return true;
      }
      return false;
    }
    throw PyError(line,
        "Argument of type '${_typeName(container)}' is not iterable",
        type: 'TypeError');
  }

  /// Compares two values. Returns a negative number, 0 or a positive number.
  int _cmpValues(dynamic a, dynamic b, int line) {
    final x = a is bool ? (a ? 1 : 0) : a;
    final y = b is bool ? (b ? 1 : 0) : b;
    if (x is num && y is num) return x.compareTo(y);
    if (x is String && y is String) return x.compareTo(y);
    if (x is List && y is List) {
      final n = math.min(x.length, y.length);
      for (var i = 0; i < n; i++) {
        final c = _cmpValues(x[i], y[i], line);
        if (c != 0) return c;
      }
      return x.length.compareTo(y.length);
    }
    throw PyError(line,
        "'<' is not supported between ${_typeName(a)} and ${_typeName(b)}",
        type: 'TypeError');
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
        return (a == null && b == null) ||
            identical(a, b) ||
            (a is bool && b is bool && a == b);
      case 'is not':
        return !((a == null && b == null) ||
            identical(a, b) ||
            (a is bool && b is bool && a == b));
    }
    final c = _cmpValues(a, b, line);
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
    throw PyError(line, "Unknown operator '$op'", type: 'SyntaxError');
  }

  // ------------------------------- calls -------------------------------

  dynamic _evalCall(Call c) {
    final f = c.func;
    if (f is Attribute) return _callAttribute(c, f);
    final callee = _eval(f);
    final args = <dynamic>[for (final a in c.args) _eval(a)];
    final kwargs = <String, dynamic>{};
    c.kwargs.forEach((k, v) {
      kwargs[k] = _eval(v);
    });
    return _callValue(callee, args, kwargs, c.line);
  }

  dynamic _callValue(dynamic callee, List<dynamic> args,
      Map<String, dynamic> kwargs, int line) {
    if (callee is _UserFunc) return _callUser(callee, args, kwargs, line);
    if (callee is _BoundMethod) {
      return _callUser(callee.func, <dynamic>[callee.self, ...args], kwargs, line);
    }
    if (callee is _Lambda) return _callLambda(callee, args, kwargs, line);
    if (callee is _Class) return _instantiate(callee, args, kwargs, line);
    if (callee is _Builtin) return _builtin(callee.name, args, kwargs, line);
    throw PyError(line, "'${_typeName(callee)}' object is not callable",
        type: 'TypeError');
  }

  dynamic _callLambda(_Lambda f, List<dynamic> args,
      Map<String, dynamic> kwargs, int line) {
    final params = f.node.params;
    if (args.length > params.length) {
      throw PyError(line,
          'lambda takes ${params.length} argument(s) but ${args.length} were given',
          type: 'TypeError');
    }
    final frame = _Frame('<lambda>', parent: f.closure);
    for (var i = 0; i < params.length; i++) {
      dynamic v = _noDefault;
      if (i < args.length) {
        v = args[i];
      } else if (kwargs.containsKey(params[i])) {
        v = kwargs[params[i]];
      } else if (!identical(f.defaults[i], _noDefault)) {
        v = f.defaults[i];
      }
      if (identical(v, _noDefault)) {
        throw PyError(line, "lambda is missing the argument '${params[i]}'",
            type: 'TypeError');
      }
      frame.vars[params[i]] = v;
    }
    _stack.add(frame);
    final result = _eval(f.node.body);
    _stack.removeLast();
    return result;
  }

  dynamic _callUser(_UserFunc f, List<dynamic> args,
      Map<String, dynamic> kwargs, int line) {
    final def = f.def;
    final params = def.params;
    if (args.length > params.length) {
      throw PyError(line,
          '${def.name}() takes ${params.length} argument(s) but ${args.length} were given',
          type: 'TypeError');
    }
    final values = List<dynamic>.filled(params.length, _noDefault);
    for (var i = 0; i < args.length; i++) {
      values[i] = args[i];
    }
    kwargs.forEach((k, v) {
      final idx = params.indexOf(k);
      if (idx < 0) {
        throw PyError(line,
            "${def.name}() got an unexpected keyword argument '$k'",
            type: 'TypeError');
      }
      if (idx < args.length) {
        throw PyError(line, "${def.name}() got multiple values for '$k'",
            type: 'TypeError');
      }
      values[idx] = v;
    });
    for (var i = 0; i < params.length; i++) {
      if (identical(values[i], _noDefault)) {
        final d = f.defaults[i];
        if (identical(d, _noDefault)) {
          throw PyError(line,
              "${def.name}() is missing the argument '${params[i]}'",
              type: 'TypeError');
        }
        values[i] = d;
      }
    }
    if (_stack.length >= maxDepth) {
      throw PyError(line, 'Recursion is too deep (limit is $maxDepth calls)',
          type: 'RecursionError', fatal: true);
    }
    _reads.clear();
    _writes.clear();
    _dictReads.clear();
    _dictWrites.clear();

    final owner = f.owner;
    final hasSelf = owner != null && !def.decorators.contains('staticmethod');
    final Iterable<dynamic> shown = hasSelf ? values.skip(1) : values;
    final label = owner != null
        ? '${owner.name}.${def.name}(${shown.map(_repr).join(', ')})'
        : '${def.name}(${shown.map(_repr).join(', ')})';

    final frame = _Frame(label, parent: f.closure, owner: owner);
    for (var i = 0; i < params.length; i++) {
      frame.vars[params[i]] = values[i];
    }
    if (hasSelf && params.isNotEmpty) frame.selfValue = values[0];
    _stack.add(frame);
    _emit(def.line, _lineText(def.line),
        'Call $label: a new frame is created with its own variables');
    final flow = _execBlock(def.body);
    final result = flow == _Flow.ret ? _retVal : null;
    _retVal = null;
    _stack.removeLast();
    _curLine = line;
    _note = 'Back from ${def.name}() with result ${_repr(result)}';
    return result;
  }

  dynamic _instantiate(_Class cls, List<dynamic> args,
      Map<String, dynamic> kwargs, int line) {
    final inst = _Instance(cls);
    final init = cls.findMethod('__init__');
    if (init != null) {
      _callUser(init, <dynamic>[inst, ...args], kwargs, line);
    } else if (cls.exceptionBase != null) {
      inst.fields['message'] = args.isEmpty ? '' : _str(args[0]);
    } else if (args.isNotEmpty || kwargs.isNotEmpty) {
      throw PyError(line, '${cls.name}() takes no arguments',
          type: 'TypeError');
    }
    _note = 'Created an object of class ${cls.name}';
    return inst;
  }

  dynamic _getAttr(dynamic obj, String name, int line) {
    if (obj is _Instance) {
      if (obj.fields.containsKey(name)) return obj.fields[name];
      final m = obj.cls.findMethod(name);
      if (m != null) {
        final deco = m.def.decorators;
        if (deco.contains('property')) {
          return _callUser(m, <dynamic>[obj], <String, dynamic>{}, line);
        }
        if (deco.contains('staticmethod')) return m;
        if (deco.contains('classmethod')) return _BoundMethod(obj.cls, m);
        return _BoundMethod(obj, m);
      }
      if (obj.cls.hasAttr(name)) return obj.cls.getAttr(name);
      throw PyError(line, "'${obj.cls.name}' object has no attribute '$name'",
          type: 'AttributeError');
    }
    if (obj is _Class) {
      final m = obj.findMethod(name);
      if (m != null) {
        if (m.def.decorators.contains('classmethod')) {
          return _BoundMethod(obj, m);
        }
        return m;
      }
      if (obj.hasAttr(name)) return obj.getAttr(name);
      if (name == '__name__') return obj.name;
      throw PyError(line, "class '${obj.name}' has no attribute '$name'",
          type: 'AttributeError');
    }
    if (obj is _Module) return _moduleMember(obj, name, line);
    if (obj is _PyExc && name == 'args') {
      return _Tuple(<dynamic>[obj.message]);
    }
    throw PyError(line, "'${_typeName(obj)}' object has no attribute '$name'",
        type: 'AttributeError');
  }

  dynamic _callAttribute(Call c, Attribute a) {
    final base = a.obj;
    if (base is Call &&
        base.func is Name &&
        (base.func as Name).id == 'super' &&
        base.args.isEmpty) {
      return _callSuper(c, a);
    }
    final obj = _eval(base);
    final args = <dynamic>[for (final x in c.args) _eval(x)];
    final kwargs = <String, dynamic>{};
    c.kwargs.forEach((k, v) {
      kwargs[k] = _eval(v);
    });
    if (obj is _Instance || obj is _Class || obj is _Module) {
      final fn = _getAttr(obj, a.name, c.line);
      return _callValue(fn, args, kwargs, c.line);
    }
    return _callMethod(obj, a, args, kwargs, c);
  }

  dynamic _callSuper(Call c, Attribute a) {
    _Frame? fr;
    for (var i = _stack.length - 1; i >= 0; i--) {
      if (_stack[i].owner != null) {
        fr = _stack[i];
        break;
      }
    }
    if (fr == null || fr.owner == null) {
      throw PyError(c.line, 'super() can only be used inside a method',
          type: 'RuntimeError');
    }
    final owner = fr.owner!;
    final self = fr.selfValue;
    final args = <dynamic>[for (final x in c.args) _eval(x)];
    final kwargs = <String, dynamic>{};
    c.kwargs.forEach((k, v) {
      kwargs[k] = _eval(v);
    });
    final start = owner.base;
    if (start != null) {
      final m = start.findMethod(a.name);
      if (m != null) {
        return _callUser(m, <dynamic>[self, ...args], kwargs, c.line);
      }
    }
    if (owner.exceptionBase != null && a.name == '__init__' && self is _Instance) {
      self.fields['message'] = args.isEmpty ? '' : _str(args[0]);
      return null;
    }
    if (a.name == '__init__') return null; // object.__init__ does nothing
    throw PyError(c.line, "super() has no method '${a.name}'",
        type: 'AttributeError');
  }

  bool _isInstanceOf(dynamic v, dynamic t, int line) {
    if (t is List) {
      for (final x in t) {
        if (_isInstanceOf(v, x, line)) return true;
      }
      return false;
    }
    if (t is _Class) return v is _Instance && v.cls.isSubclassOf(t);
    if (t is _Builtin) {
      switch (t.name) {
        case 'int':
          return v is int || v is bool;
        case 'float':
          return v is double;
        case 'str':
          return v is String;
        case 'bool':
          return v is bool;
        case 'list':
          return v is List && v is! _Tuple;
        case 'tuple':
          return v is _Tuple;
        case 'dict':
          return v is Map;
        case 'set':
          return v is Set;
        case 'object':
          return true;
        default:
          if (_excNames.contains(t.name)) {
            if (v is _PyExc) return _excMatches(v.type, t.name);
            if (v is _Instance) return _instMatchesBuiltin(v, t.name);
          }
          return false;
      }
    }
    throw PyError(line, 'isinstance() needs a type as the second argument',
        type: 'TypeError');
  }

  // ------------------------------ sequences ----------------------------

  List<dynamic> _toList(dynamic v, int line) {
    if (v is List) return List<dynamic>.of(v);
    if (v is String) return v.split('');
    if (v is Map) return v.keys.toList();
    if (v is Set) return v.toList();
    if (v is _RangeVal) {
      if (v.length > 100000) {
        throw PyError(line, 'This range is too large for the visualizer',
            type: 'OverflowError');
      }
      return <dynamic>[for (var i = 0; i < v.length; i++) v.at(i)];
    }
    throw PyError(line, "'${_typeName(v)}' object is not iterable",
        type: 'TypeError');
  }

  int _lenOf(dynamic v, int line) {
    if (v is List) return v.length;
    if (v is String) return v.length;
    if (v is Map) return v.length;
    if (v is Set) return v.length;
    if (v is _RangeVal) return v.length;
    throw PyError(line, "Object of type '${_typeName(v)}' has no len()",
        type: 'TypeError');
  }

  /// A stable sort (equal items keep their order, like Python).
  List<dynamic> _sortedList(
      List<dynamic> items, dynamic keyFn, bool reverse, int line) {
    final keys = <dynamic>[
      for (final x in items)
        keyFn == null
            ? x
            : _callValue(keyFn, <dynamic>[x], <String, dynamic>{}, line),
    ];
    final order = List<int>.generate(items.length, (i) => i);
    order.sort((i, j) {
      var c = _cmpValues(keys[i], keys[j], line);
      if (reverse) c = -c;
      return c != 0 ? c : i.compareTo(j);
    });
    return <dynamic>[for (final i in order) items[i]];
  }

  void _needArgs(List<dynamic> args, int count, String name, int line) {
    if (args.length != count) {
      throw PyError(line,
          '$name() needs $count argument(s) but got ${args.length}',
          type: 'TypeError');
    }
  }

  double _roundHalfEven(double x, int line) {
    if (x.isNaN || x.isInfinite) {
      throw PyError(line, 'Cannot round this number', type: 'OverflowError');
    }
    if ((x - x.truncateToDouble()).abs() == 0.5) {
      return 2 * (x / 2).roundToDouble();
    }
    return x.roundToDouble();
  }

  // ------------------------------ built-ins ----------------------------

  dynamic _builtin(String name, List<dynamic> args,
      Map<String, dynamic> kwargs, int line) {
    if (name.startsWith('math.')) {
      return _mathFunc(name.substring(5), args, line);
    }
    if (_excNames.contains(name)) {
      return _PyExc(name, args.isEmpty ? '' : _str(args[0]));
    }
    switch (name) {
      case 'print':
        {
          final sepArg = kwargs['sep'];
          final endArg = kwargs['end'];
          final sep = sepArg == null ? ' ' : _str(sepArg);
          final end = endArg == null ? '\n' : _str(endArg);
          final text = args.map(_str).join(sep) + end;
          _writeOut(text);
          _note =
              'Printed: ${text.endsWith('\n') ? text.substring(0, text.length - 1) : text}';
          return null;
        }

      case 'input':
        {
          final prompt = args.isEmpty ? '' : _str(args[0]);
          if (_inputPos >= inputs.length) {
            throw PyError(line,
                'input() was called but there is no input left. Type the values in the Input box, one per line.',
                type: 'EOFError');
          }
          final value = inputs[_inputPos++];
          _writeOut('$prompt$value\n');
          _note = 'Read the input: $value';
          return value;
        }

      case 'len':
        {
          _needArgs(args, 1, 'len', line);
          return _lenOf(args[0], line);
        }

      case 'range':
        {
          if (args.isEmpty || args.length > 3 || args.any((a) => a is! int)) {
            throw PyError(line, 'range() needs 1 to 3 whole numbers',
                type: 'TypeError');
          }
          final ints = args.cast<int>();
          final start = ints.length == 1 ? 0 : ints[0];
          final stop = ints.length == 1 ? ints[0] : ints[1];
          final step = ints.length == 3 ? ints[2] : 1;
          if (step == 0) {
            throw PyError(line, 'range() step cannot be 0', type: 'ValueError');
          }
          return _RangeVal(start, stop, step);
        }

      case 'int':
        {
          if (args.isEmpty) return 0;
          final v = args[0];
          if (args.length == 2 && v is String && args[1] is int) {
            final r = int.tryParse(v.trim(), radix: args[1] as int);
            if (r == null) {
              throw PyError(line, "invalid literal for int(): '$v'",
                  type: 'ValueError');
            }
            return r;
          }
          if (v is bool) return v ? 1 : 0;
          if (v is int) return v;
          if (v is double) {
            if (v.isNaN || v.isInfinite) {
              throw PyError(line, 'Cannot convert this float to int',
                  type: 'ValueError');
            }
            return v.truncate();
          }
          if (v is String) {
            final parsed = int.tryParse(v.trim().replaceAll('_', ''));
            if (parsed == null) {
              throw PyError(line, "invalid literal for int(): '$v'",
                  type: 'ValueError');
            }
            return parsed;
          }
          throw PyError(line, 'Cannot convert ${_typeName(v)} to int',
              type: 'TypeError');
        }

      case 'float':
        {
          if (args.isEmpty) return 0.0;
          final v = args[0];
          if (v is bool) return v ? 1.0 : 0.0;
          if (v is num) return v.toDouble();
          if (v is String) {
            final t = v.trim().toLowerCase();
            if (t == 'inf' || t == '+inf' || t == 'infinity') {
              return double.infinity;
            }
            if (t == '-inf' || t == '-infinity') return double.negativeInfinity;
            if (t == 'nan') return double.nan;
            final parsed = double.tryParse(t.replaceAll('_', ''));
            if (parsed == null) {
              throw PyError(line, "could not convert string to float: '$v'",
                  type: 'ValueError');
            }
            return parsed;
          }
          throw PyError(line, 'Cannot convert ${_typeName(v)} to float',
              type: 'TypeError');
        }

      case 'str':
        return args.isEmpty ? '' : _str(args[0]);

      case 'bool':
        return args.isEmpty ? false : _truthy(args[0]);

      case 'repr':
        {
          _needArgs(args, 1, 'repr', line);
          return _repr(args[0]);
        }

      case 'abs':
        {
          _needArgs(args, 1, 'abs', line);
          final v = args[0];
          if (v is bool) return v ? 1 : 0;
          if (v is num) return v.abs();
          throw PyError(line, 'abs() needs a number', type: 'TypeError');
        }

      case 'round':
        {
          if (args.isEmpty || args.length > 2) {
            throw PyError(line, 'round() needs 1 or 2 arguments',
                type: 'TypeError');
          }
          final v = args[0];
          if (v is! num) {
            throw PyError(line, 'round() needs a number', type: 'TypeError');
          }
          if (args.length == 1) {
            if (v is int) return v;
            return _roundHalfEven(v.toDouble(), line).toInt();
          }
          final nd = args[1];
          if (nd is! int) {
            throw PyError(line, 'round() digits must be a whole number',
                type: 'TypeError');
          }
          final f = math.pow(10, nd).toDouble();
          return _roundHalfEven(v.toDouble() * f, line) / f;
        }

      case 'pow':
        {
          if (args.length == 3) {
            final a0 = args[0];
            final b0 = args[1];
            final m0 = args[2];
            if (a0 is int && b0 is int && m0 is int && b0 >= 0 && m0 != 0) {
              return BigInt.from(a0)
                  .modPow(BigInt.from(b0), BigInt.from(m0))
                  .toInt();
            }
            throw PyError(line, 'pow() with 3 arguments needs whole numbers',
                type: 'TypeError');
          }
          _needArgs(args, 2, 'pow', line);
          return _binop('**', args[0], args[1], line);
        }

      case 'divmod':
        {
          _needArgs(args, 2, 'divmod', line);
          return _Tuple(<dynamic>[
            _binop('//', args[0], args[1], line),
            _binop('%', args[0], args[1], line),
          ]);
        }

      case 'min':
      case 'max':
        {
          final keyFn = kwargs['key'];
          final List<dynamic> items =
              args.length == 1 ? _toList(args[0], line) : args;
          if (items.isEmpty) {
            if (kwargs.containsKey('default')) return kwargs['default'];
            throw PyError(line, '$name() needs at least one value',
                type: 'ValueError');
          }
          dynamic best = items.first;
          dynamic bestKey = keyFn == null
              ? best
              : _callValue(keyFn, <dynamic>[best], <String, dynamic>{}, line);
          for (final item in items.skip(1)) {
            final k = keyFn == null
                ? item
                : _callValue(keyFn, <dynamic>[item], <String, dynamic>{}, line);
            final c = _cmpValues(k, bestKey, line);
            if (name == 'min' ? c < 0 : c > 0) {
              best = item;
              bestKey = k;
            }
          }
          return best;
        }

      case 'sum':
        {
          if (args.isEmpty || args.length > 2) {
            throw PyError(line, 'sum() needs 1 or 2 arguments',
                type: 'TypeError');
          }
          dynamic total = args.length > 1 ? args[1] : 0;
          for (final item in _toList(args[0], line)) {
            total = _binop('+', total, item, line);
          }
          return total;
        }

      case 'list':
        return args.isEmpty ? <dynamic>[] : _toList(args[0], line);

      case 'tuple':
        return _Tuple(args.isEmpty ? <dynamic>[] : _toList(args[0], line));

      case 'set':
        {
          final s = <dynamic>{};
          if (args.isNotEmpty) {
            for (final x in _toList(args[0], line)) {
              _checkKey(x, line);
              s.add(x);
            }
          }
          return s;
        }

      case 'dict':
        {
          final map = <dynamic, dynamic>{};
          if (args.isNotEmpty) {
            final first = args[0];
            if (first is Map) {
              map.addAll(first);
            } else {
              for (final pair in _toList(first, line)) {
                if (pair is List && pair.length == 2) {
                  _checkKey(pair[0], line);
                  map[pair[0]] = pair[1];
                } else {
                  throw PyError(line, 'dict() needs pairs of (key, value)',
                      type: 'ValueError');
                }
              }
            }
          }
          kwargs.forEach((k, v) {
            map[k] = v;
          });
          return map;
        }

      case 'enumerate':
        {
          if (args.isEmpty) {
            throw PyError(line, 'enumerate() needs an iterable',
                type: 'TypeError');
          }
          final startArg = args.length > 1 ? args[1] : kwargs['start'];
          final start = startArg is int ? startArg : 0;
          final items = _toList(args[0], line);
          return <dynamic>[
            for (var i = 0; i < items.length; i++)
              _Tuple(<dynamic>[i + start, items[i]]),
          ];
        }

      case 'zip':
        {
          if (args.isEmpty) return <dynamic>[];
          final lists = [for (final a in args) _toList(a, line)];
          var n = lists.first.length;
          for (final l in lists) {
            if (l.length < n) n = l.length;
          }
          return <dynamic>[
            for (var i = 0; i < n; i++)
              _Tuple(<dynamic>[for (final l in lists) l[i]]),
          ];
        }

      case 'reversed':
        {
          _needArgs(args, 1, 'reversed', line);
          return _toList(args[0], line).reversed.toList();
        }

      case 'sorted':
        {
          _needArgs(args, 1, 'sorted', line);
          return _sortedList(_toList(args[0], line), kwargs['key'],
              _truthy(kwargs['reverse']), line);
        }

      case 'any':
        {
          _needArgs(args, 1, 'any', line);
          return _toList(args[0], line).any(_truthy);
        }

      case 'all':
        {
          _needArgs(args, 1, 'all', line);
          return _toList(args[0], line).every(_truthy);
        }

      case 'map':
        {
          if (args.length < 2) {
            throw PyError(line, 'map() needs a function and an iterable',
                type: 'TypeError');
          }
          final fn = args[0];
          final lists = [
            for (var i = 1; i < args.length; i++) _toList(args[i], line),
          ];
          var n = lists.first.length;
          for (final l in lists) {
            if (l.length < n) n = l.length;
          }
          return <dynamic>[
            for (var i = 0; i < n; i++)
              _callValue(fn, <dynamic>[for (final l in lists) l[i]],
                  <String, dynamic>{}, line),
          ];
        }

      case 'filter':
        {
          _needArgs(args, 2, 'filter', line);
          final fn = args[0];
          final out = <dynamic>[];
          for (final x in _toList(args[1], line)) {
            final keep = fn == null
                ? _truthy(x)
                : _truthy(_callValue(
                    fn, <dynamic>[x], <String, dynamic>{}, line));
            if (keep) out.add(x);
          }
          return out;
        }

      case 'chr':
        {
          _needArgs(args, 1, 'chr', line);
          final v = args[0];
          if (v is! int || v < 0 || v > 0x10FFFF) {
            throw PyError(line, 'chr() needs a whole number from 0 to 1114111',
                type: 'ValueError');
          }
          return String.fromCharCode(v);
        }

      case 'ord':
        {
          _needArgs(args, 1, 'ord', line);
          final v = args[0];
          if (v is! String || v.runes.length != 1) {
            throw PyError(line, 'ord() needs a string of one character',
                type: 'TypeError');
          }
          return v.runes.first;
        }

      case 'type':
        {
          _needArgs(args, 1, 'type', line);
          final v = args[0];
          if (v is _Instance) return _TypeVal('__main__.${v.cls.name}');
          return _TypeVal(_typeName(v));
        }

      case 'isinstance':
        {
          _needArgs(args, 2, 'isinstance', line);
          return _isInstanceOf(args[0], args[1], line);
        }

      case 'bin':
      case 'hex':
      case 'oct':
        {
          _needArgs(args, 1, name, line);
          final v = args[0];
          if (v is! int) {
            throw PyError(line, '$name() needs a whole number',
                type: 'TypeError');
          }
          final radix = name == 'bin' ? 2 : (name == 'hex' ? 16 : 8);
          final prefix = name == 'bin' ? '0b' : (name == 'hex' ? '0x' : '0o');
          return (v < 0 ? '-' : '') + prefix + v.abs().toRadixString(radix);
        }

      case 'format':
        {
          if (args.isEmpty || args.length > 2) {
            throw PyError(line, 'format() needs 1 or 2 arguments',
                type: 'TypeError');
          }
          return _formatValue(args[0], args.length > 1 ? _str(args[1]) : '', line);
        }

      case 'object':
        return _Instance(_Class('object', null, null));
    }
    throw PyError(line, "Function '$name' is not supported yet",
        type: 'NotImplementedError');
  }

  dynamic _mathFunc(String fn, List<dynamic> args, int line) {
    double d(int i) {
      if (i >= args.length) {
        throw PyError(line, 'math.$fn() needs more arguments',
            type: 'TypeError');
      }
      final v = args[i];
      if (v is bool) return v ? 1.0 : 0.0;
      if (v is num) return v.toDouble();
      throw PyError(line, 'math.$fn() needs a number', type: 'TypeError');
    }

    int whole(int i) {
      if (i >= args.length || args[i] is! int) {
        throw PyError(line, 'math.$fn() needs whole numbers', type: 'TypeError');
      }
      return args[i] as int;
    }

    switch (fn) {
      case 'sqrt':
        {
          final x = d(0);
          if (x < 0) {
            throw PyError(line, 'math domain error', type: 'ValueError');
          }
          return math.sqrt(x);
        }
      case 'floor':
        return d(0).floor();
      case 'ceil':
        return d(0).ceil();
      case 'trunc':
        return d(0).truncate();
      case 'fabs':
        return d(0).abs();
      case 'pow':
        return math.pow(d(0), d(1)).toDouble();
      case 'exp':
        return math.exp(d(0));
      case 'log':
        {
          final x = d(0);
          if (x <= 0) {
            throw PyError(line, 'math domain error', type: 'ValueError');
          }
          if (args.length > 1) return math.log(x) / math.log(d(1));
          return math.log(x);
        }
      case 'log10':
        {
          final x = d(0);
          if (x <= 0) {
            throw PyError(line, 'math domain error', type: 'ValueError');
          }
          return math.log(x) / math.ln10;
        }
      case 'log2':
        {
          final x = d(0);
          if (x <= 0) {
            throw PyError(line, 'math domain error', type: 'ValueError');
          }
          return math.log(x) / math.ln2;
        }
      case 'sin':
        return math.sin(d(0));
      case 'cos':
        return math.cos(d(0));
      case 'tan':
        return math.tan(d(0));
      case 'asin':
        return math.asin(d(0));
      case 'acos':
        return math.acos(d(0));
      case 'atan':
        return math.atan(d(0));
      case 'atan2':
        return math.atan2(d(0), d(1));
      case 'radians':
        return d(0) * math.pi / 180;
      case 'degrees':
        return d(0) * 180 / math.pi;
      case 'hypot':
        return math.sqrt(d(0) * d(0) + d(1) * d(1));
      case 'gcd':
        {
          var a = whole(0).abs();
          var b = whole(1).abs();
          while (b != 0) {
            final t = a % b;
            a = b;
            b = t;
          }
          return a;
        }
      case 'factorial':
        {
          final n = whole(0);
          if (n < 0) {
            throw PyError(line, 'factorial() needs a number that is 0 or more',
                type: 'ValueError');
          }
          num result = 1;
          for (var i = 2; i <= n; i++) {
            result = _checkNum(result * i, line);
          }
          return result;
        }
      case 'isqrt':
        {
          final n = whole(0);
          if (n < 0) {
            throw PyError(line, 'isqrt() needs a number that is 0 or more',
                type: 'ValueError');
          }
          var r = math.sqrt(n).floor();
          while (r * r > n) {
            r--;
          }
          while ((r + 1) * (r + 1) <= n) {
            r++;
          }
          return r;
        }
    }
    throw PyError(line, "math.$fn() is not supported yet",
        type: 'NotImplementedError');
  }

  // ------------------------- methods of built-in types ------------------

  String _stripText(String s, String? chars,
      {required bool left, required bool right}) {
    bool isStrip(String ch) =>
        chars == null ? ch.trim().isEmpty : chars.contains(ch);
    var start = 0;
    var end = s.length;
    if (left) {
      while (start < end && isStrip(s[start])) {
        start++;
      }
    }
    if (right) {
      while (end > start && isStrip(s[end - 1])) {
        end--;
      }
    }
    return s.substring(start, end);
  }

  String _titleCase(String s) {
    final b = StringBuffer();
    var newWord = true;
    final letter = RegExp(r'[A-Za-z]');
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (letter.hasMatch(ch)) {
        b.write(newWord ? ch.toUpperCase() : ch.toLowerCase());
        newWord = false;
      } else {
        b.write(ch);
        newWord = true;
      }
    }
    return b.toString();
  }

  dynamic _callMethod(dynamic obj, Attribute a, List<dynamic> args,
      Map<String, dynamic> kwargs, Call c) {
    final line = c.line;
    final name = a.name;
    final base = a.obj;
    final arrName = base is Name ? base.id : null;

    // ---------------------------- lists ----------------------------
    if (obj is List && obj is! _Tuple) {
      void markAll() {
        if (_tracking && arrName != null) {
          _writes
              .putIfAbsent(arrName, () => <int>{})
              .addAll([for (var i = 0; i < obj.length; i++) i]);
        }
      }

      switch (name) {
        case 'append':
          {
            _needArgs(args, 1, 'append', line);
            obj.add(args[0]);
            if (_tracking && arrName != null) {
              _writes.putIfAbsent(arrName, () => <int>{}).add(obj.length - 1);
            }
            _note = 'Added ${_repr(args[0])} to the end of ${a.obj.src}';
            return null;
          }
        case 'pop':
          {
            if (obj.isEmpty) {
              throw PyError(line, 'Cannot pop from an empty list',
                  type: 'IndexError');
            }
            var popIdx = obj.length - 1;
            if (args.isNotEmpty) {
              final popGiven = args[0];
              if (popGiven is! int) {
                throw PyError(line, 'pop() index must be a whole number',
                    type: 'TypeError');
              }
              popIdx = _normIndex(popGiven, obj.length, line);
            }
            final removed = obj.removeAt(popIdx);
            _note = 'Removed ${_repr(removed)} from ${a.obj.src}';
            return removed;
          }
        case 'insert':
          {
            _needArgs(args, 2, 'insert', line);
            final insGiven = args[0];
            if (insGiven is! int) {
              throw PyError(line, 'insert() index must be a whole number',
                  type: 'TypeError');
            }
            var insIdx = insGiven < 0 ? insGiven + obj.length : insGiven;
            if (insIdx < 0) insIdx = 0;
            if (insIdx > obj.length) insIdx = obj.length;
            obj.insert(insIdx, args[1]);
            if (_tracking && arrName != null) {
              _writes.putIfAbsent(arrName, () => <int>{}).add(insIdx);
            }
            _note = 'Inserted ${_repr(args[1])} at index $insIdx of ${a.obj.src}';
            return null;
          }
        case 'extend':
          {
            _needArgs(args, 1, 'extend', line);
            obj.addAll(_toList(args[0], line));
            _note = 'Added all items to the end of ${a.obj.src}';
            return null;
          }
        case 'reverse':
          {
            final reversed = obj.reversed.toList();
            obj
              ..clear()
              ..addAll(reversed);
            markAll();
            _note = 'Reversed ${a.obj.src}';
            return null;
          }
        case 'sort':
          {
            final sorted = _sortedList(List<dynamic>.of(obj), kwargs['key'],
                _truthy(kwargs['reverse']), line);
            obj
              ..clear()
              ..addAll(sorted);
            markAll();
            _note = 'Sorted ${a.obj.src}';
            return null;
          }
        case 'remove':
          {
            _needArgs(args, 1, 'remove', line);
            final rmAt = obj.indexWhere((e) => _eq(e, args[0]));
            if (rmAt < 0) {
              throw PyError(line, 'Value is not in the list', type: 'ValueError');
            }
            obj.removeAt(rmAt);
            _note = 'Removed ${_repr(args[0])} from ${a.obj.src}';
            return null;
          }
        case 'index':
          {
            _needArgs(args, 1, 'index', line);
            final ixAt = obj.indexWhere((e) => _eq(e, args[0]));
            if (ixAt < 0) {
              throw PyError(line, 'Value is not in the list', type: 'ValueError');
            }
            return ixAt;
          }
        case 'count':
          {
            _needArgs(args, 1, 'count', line);
            return obj.where((e) => _eq(e, args[0])).length;
          }
        case 'copy':
          return List<dynamic>.of(obj);
        case 'clear':
          {
            obj.clear();
            _note = 'Cleared ${a.obj.src}';
            return null;
          }
      }
      throw PyError(line, "Lists have no method '$name' in this visualizer",
          type: 'AttributeError');
    }

    // ---------------------------- tuples ---------------------------
    if (obj is _Tuple) {
      switch (name) {
        case 'index':
          {
            _needArgs(args, 1, 'index', line);
            final at = obj.indexWhere((e) => _eq(e, args[0]));
            if (at < 0) {
              throw PyError(line, 'Value is not in the tuple', type: 'ValueError');
            }
            return at;
          }
        case 'count':
          {
            _needArgs(args, 1, 'count', line);
            return obj.where((e) => _eq(e, args[0])).length;
          }
      }
      throw PyError(line, "Tuples have no method '$name'", type: 'AttributeError');
    }

    // -------------------------- dictionaries -----------------------
    if (obj is Map) {
      switch (name) {
        case 'get':
          {
            if (args.isEmpty || args.length > 2) {
              throw PyError(line, 'get() needs 1 or 2 arguments',
                  type: 'TypeError');
            }
            final hasKey = obj.containsKey(args[0]);
            if (hasKey && _tracking && arrName != null) {
              _dictReads
                  .putIfAbsent(arrName, () => <String>{})
                  .add(_repr(args[0]));
            }
            if (hasKey) return obj[args[0]];
            return args.length == 2 ? args[1] : null;
          }
        case 'keys':
          return obj.keys.toList();
        case 'values':
          return obj.values.toList();
        case 'items':
          return <dynamic>[
            for (final entry in obj.entries)
              _Tuple(<dynamic>[entry.key, entry.value]),
          ];
        case 'pop':
          {
            if (args.isEmpty || args.length > 2) {
              throw PyError(line, 'pop() needs 1 or 2 arguments',
                  type: 'TypeError');
            }
            if (obj.containsKey(args[0])) {
              final removedValue = obj.remove(args[0]);
              _note = 'Removed key ${_repr(args[0])} from ${a.obj.src}';
              return removedValue;
            }
            if (args.length == 2) return args[1];
            throw PyError(line, 'Key ${_repr(args[0])} is not in the dictionary',
                type: 'KeyError');
          }
        case 'setdefault':
          {
            if (args.isEmpty || args.length > 2) {
              throw PyError(line, 'setdefault() needs 1 or 2 arguments',
                  type: 'TypeError');
            }
            if (!obj.containsKey(args[0])) {
              _checkKey(args[0], line);
              obj[args[0]] = args.length == 2 ? args[1] : null;
              if (_tracking && arrName != null) {
                _dictWrites
                    .putIfAbsent(arrName, () => <String>{})
                    .add(_repr(args[0]));
              }
            }
            return obj[args[0]];
          }
        case 'update':
          {
            if (args.isNotEmpty) {
              final other = args[0];
              if (other is! Map) {
                throw PyError(line, 'update() needs a dictionary',
                    type: 'TypeError');
              }
              obj.addAll(other);
              if (_tracking && arrName != null) {
                for (final k in other.keys) {
                  _dictWrites
                      .putIfAbsent(arrName, () => <String>{})
                      .add(_repr(k));
                }
              }
            }
            kwargs.forEach((k, v) {
              obj[k] = v;
            });
            _note = 'Updated ${a.obj.src}';
            return null;
          }
        case 'copy':
          return <dynamic, dynamic>{...obj};
        case 'clear':
          {
            obj.clear();
            _note = 'Cleared ${a.obj.src}';
            return null;
          }
      }
      throw PyError(line, "Dictionaries have no method '$name' in this visualizer",
          type: 'AttributeError');
    }

    // ------------------------------ sets ---------------------------
    if (obj is Set) {
      Set<dynamic> other(int i) {
        if (i >= args.length) {
          throw PyError(line, '$name() needs an argument', type: 'TypeError');
        }
        return <dynamic>{..._toList(args[i], line)};
      }

      switch (name) {
        case 'add':
          {
            _needArgs(args, 1, 'add', line);
            _checkKey(args[0], line);
            obj.add(args[0]);
            _note = 'Added ${_repr(args[0])} to ${a.obj.src}';
            return null;
          }
        case 'remove':
          {
            _needArgs(args, 1, 'remove', line);
            if (!obj.remove(args[0])) {
              throw PyError(line, 'Key ${_repr(args[0])} is not in the dictionary',
                  type: 'KeyError');
            }
            _note = 'Removed ${_repr(args[0])} from ${a.obj.src}';
            return null;
          }
        case 'discard':
          {
            _needArgs(args, 1, 'discard', line);
            obj.remove(args[0]);
            return null;
          }
        case 'pop':
          {
            if (obj.isEmpty) {
              throw PyError(line, 'Cannot pop from an empty set',
                  type: 'KeyError');
            }
            final first = obj.first;
            obj.remove(first);
            return first;
          }
        case 'union':
          {
            final result = <dynamic>{...obj};
            for (var i = 0; i < args.length; i++) {
              result.addAll(other(i));
            }
            return result;
          }
        case 'update':
          {
            for (var i = 0; i < args.length; i++) {
              obj.addAll(other(i));
            }
            return null;
          }
        case 'intersection':
          {
            final o = other(0);
            return <dynamic>{for (final v in obj) if (o.contains(v)) v};
          }
        case 'difference':
          {
            final o = other(0);
            return <dynamic>{for (final v in obj) if (!o.contains(v)) v};
          }
        case 'symmetric_difference':
          {
            final o = other(0);
            return <dynamic>{
              for (final v in obj) if (!o.contains(v)) v,
              for (final v in o) if (!obj.contains(v)) v,
            };
          }
        case 'issubset':
          {
            final o = other(0);
            return obj.every((v) => o.contains(v));
          }
        case 'issuperset':
          {
            final o = other(0);
            return o.every((v) => obj.contains(v));
          }
        case 'copy':
          return <dynamic>{...obj};
        case 'clear':
          {
            obj.clear();
            return null;
          }
      }
      throw PyError(line, "Sets have no method '$name' in this visualizer",
          type: 'AttributeError');
    }

    // ----------------------------- strings -------------------------
    if (obj is String) {
      switch (name) {
        case 'upper':
          return obj.toUpperCase();
        case 'lower':
          return obj.toLowerCase();
        case 'title':
          return _titleCase(obj);
        case 'capitalize':
          return obj.isEmpty
              ? obj
              : obj[0].toUpperCase() + obj.substring(1).toLowerCase();
        case 'swapcase':
          return obj.split('').map((ch) {
            final up = ch.toUpperCase();
            return ch == up ? ch.toLowerCase() : up;
          }).join();
        case 'strip':
        case 'lstrip':
        case 'rstrip':
          {
            final chars = args.isNotEmpty && args[0] is String
                ? args[0] as String
                : null;
            return _stripText(obj, chars,
                left: name != 'rstrip', right: name != 'lstrip');
          }
        case 'split':
          {
            final sepArg = args.isNotEmpty ? args[0] : kwargs['sep'];
            if (sepArg == null) {
              final t = obj.trim();
              if (t.isEmpty) return <dynamic>[];
              return <dynamic>[...t.split(RegExp(r'\s+'))];
            }
            if (sepArg is! String || sepArg.isEmpty) {
              throw PyError(line, 'split() needs a separator that is not empty',
                  type: 'ValueError');
            }
            return <dynamic>[...obj.split(sepArg)];
          }
        case 'splitlines':
          return <dynamic>[...obj.split('\n')];
        case 'join':
          {
            _needArgs(args, 1, 'join', line);
            final items = _toList(args[0], line);
            for (final x in items) {
              if (x is! String) {
                throw PyError(line, 'join() needs a list of strings',
                    type: 'TypeError');
              }
            }
            return items.join(obj);
          }
        case 'replace':
          {
            if (args.length < 2 || args[0] is! String || args[1] is! String) {
              throw PyError(line, 'replace() needs two strings',
                  type: 'TypeError');
            }
            return obj.replaceAll(args[0] as String, args[1] as String);
          }
        case 'startswith':
          {
            _needArgs(args, 1, 'startswith', line);
            return args[0] is String && obj.startsWith(args[0] as String);
          }
        case 'endswith':
          {
            _needArgs(args, 1, 'endswith', line);
            return args[0] is String && obj.endsWith(args[0] as String);
          }
        case 'find':
          {
            _needArgs(args, 1, 'find', line);
            return args[0] is String ? obj.indexOf(args[0] as String) : -1;
          }
        case 'rfind':
          {
            _needArgs(args, 1, 'rfind', line);
            return args[0] is String ? obj.lastIndexOf(args[0] as String) : -1;
          }
        case 'index':
          {
            _needArgs(args, 1, 'index', line);
            final at = args[0] is String ? obj.indexOf(args[0] as String) : -1;
            if (at < 0) {
              throw PyError(line, 'Substring is not found', type: 'ValueError');
            }
            return at;
          }
        case 'count':
          {
            _needArgs(args, 1, 'count', line);
            final sub = args[0];
            if (sub is! String) {
              throw PyError(line, 'count() needs a string', type: 'TypeError');
            }
            if (sub.isEmpty) return obj.length + 1;
            return obj.split(sub).length - 1;
          }
        case 'isdigit':
          return obj.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(obj);
        case 'isalpha':
          return obj.isNotEmpty && RegExp(r'^[A-Za-z]+$').hasMatch(obj);
        case 'isalnum':
          return obj.isNotEmpty && RegExp(r'^[A-Za-z0-9]+$').hasMatch(obj);
        case 'isspace':
          return obj.isNotEmpty && obj.trim().isEmpty;
        case 'isupper':
          return obj != obj.toLowerCase() && obj == obj.toUpperCase();
        case 'islower':
          return obj != obj.toUpperCase() && obj == obj.toLowerCase();
        case 'zfill':
          {
            _needArgs(args, 1, 'zfill', line);
            final w = args[0];
            if (w is! int) {
              throw PyError(line, 'zfill() needs a whole number',
                  type: 'TypeError');
            }
            final neg = obj.startsWith('-') || obj.startsWith('+');
            final digits = neg ? obj.substring(1) : obj;
            final sign = neg ? obj[0] : '';
            return sign + digits.padLeft(math.max(0, w - sign.length), '0');
          }
        case 'ljust':
        case 'rjust':
        case 'center':
          {
            if (args.isEmpty || args[0] is! int) {
              throw PyError(line, '$name() needs a width', type: 'TypeError');
            }
            final w = args[0] as int;
            final fillChar = args.length > 1 && args[1] is String
                ? args[1] as String
                : ' ';
            if (w <= obj.length) return obj;
            final pad = w - obj.length;
            if (name == 'ljust') return obj + fillChar * pad;
            if (name == 'rjust') return fillChar * pad + obj;
            final left = pad ~/ 2;
            return fillChar * left + obj + fillChar * (pad - left);
          }
        case 'format':
          return _strFormat(obj, args, kwargs, line);
      }
      throw PyError(line, "Strings have no method '$name' in this visualizer",
          type: 'AttributeError');
    }

    throw PyError(line, "'${_typeName(obj)}' has no method '$name'",
        type: 'AttributeError');
  }
}