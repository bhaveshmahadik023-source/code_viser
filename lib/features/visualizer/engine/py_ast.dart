// Tree classes that describe the user's Python code.

// ----------------------------- Expressions -----------------------------

abstract class Expr {
  const Expr(this.line, this.src);

  /// Line where the expression starts (1-based).
  final int line;

  /// The source text of the expression, for example "arr[j + 1]".
  final String src;
}

class Literal extends Expr {
  const Literal(super.line, super.src, this.value);
  final Object? value; // int, double, String, bool or null (None)
}

class Name extends Expr {
  const Name(super.line, super.src, this.id);
  final String id;
}

class ListLit extends Expr {
  const ListLit(super.line, super.src, this.items);
  final List<Expr> items;
}

class TupleLit extends Expr {
  const TupleLit(super.line, super.src, this.items);
  final List<Expr> items;
}

class SetLit extends Expr {
  const SetLit(super.line, super.src, this.items);
  final List<Expr> items;
}

class DictLit extends Expr {
  const DictLit(super.line, super.src, this.keys, this.values);
  final List<Expr> keys;
  final List<Expr> values;
}

/// One {expression:spec} part of an f-string.
class FStringField {
  const FStringField(this.expr, this.spec, this.conv);
  final Expr expr;
  final String spec; // format spec such as ".2f" (empty if none)
  final String? conv; // "r" or "s" for !r / !s (null if none)
}

/// An f-string. [parts] holds String (plain text) and FStringField items.
class JoinedStr extends Expr {
  const JoinedStr(super.line, super.src, this.parts);
  final List<Object> parts;
}

class BinOp extends Expr {
  const BinOp(super.line, super.src, this.op, this.left, this.right);
  final String op; // + - * / // % ** | & ^ << >>
  final Expr left;
  final Expr right;
}

class UnaryOp extends Expr {
  const UnaryOp(super.line, super.src, this.op, this.operand);
  final String op; // - + ~ not
  final Expr operand;
}

class BoolOp extends Expr {
  const BoolOp(super.line, super.src, this.op, this.left, this.right);
  final String op; // and / or
  final Expr left;
  final Expr right;
}

class Compare extends Expr {
  const Compare(super.line, super.src, this.left, this.ops, this.rights);
  final Expr left;
  final List<String> ops; // < > <= >= == != in, not in, is, is not
  final List<Expr> rights;
}

class Subscript extends Expr {
  const Subscript(super.line, super.src, this.target, this.index);
  final Expr target;
  final Expr index; // an expression or a SliceExpr
}

/// a[lower:upper:step]. Each part can be null.
class SliceExpr extends Expr {
  const SliceExpr(super.line, super.src, this.lower, this.upper, this.step);
  final Expr? lower;
  final Expr? upper;
  final Expr? step;
}

class Call extends Expr {
  const Call(
    super.line,
    super.src,
    this.func,
    this.args, [
    this.kwargs = const <String, Expr>{},
  ]);
  final Expr func;
  final List<Expr> args;
  final Map<String, Expr> kwargs;
}

class Attribute extends Expr {
  const Attribute(super.line, super.src, this.obj, this.name);
  final Expr obj;
  final String name;
}

class IfExp extends Expr {
  const IfExp(super.line, super.src, this.test, this.body, this.orelse);
  final Expr test;
  final Expr body;
  final Expr orelse;
}

class Lambda extends Expr {
  const Lambda(super.line, super.src, this.params, this.defaults, this.body);
  final List<String> params;
  final List<Expr?> defaults; // same length as params (null = no default)
  final Expr body;
}

/// One "for target in iter if cond" part of a comprehension.
class CompClause {
  const CompClause(this.target, this.iter, this.conds);
  final Expr target;
  final Expr iter;
  final List<Expr> conds;
}

/// List, set or dict comprehension, or a generator expression.
class Comp extends Expr {
  const Comp(super.line, super.src, this.kind, this.elt, this.valueElt, this.clauses);
  final String kind; // list, set, dict or gen
  final Expr elt; // the item (or the key for a dict)
  final Expr? valueElt; // the value for a dict
  final List<CompClause> clauses;
}

// ----------------------------- Statements ------------------------------

abstract class Stmt {
  const Stmt(this.line);
  final int line;
}

class ExprStmt extends Stmt {
  const ExprStmt(super.line, this.expr);
  final Expr expr;
}

class Assign extends Stmt {
  const Assign(super.line, this.target, this.value,
      [this.extraTargets = const <Expr>[]]);
  final Expr target; // Name, Subscript, Attribute or TupleLit
  final Expr value;
  final List<Expr> extraTargets; // for a = b = value
}

class AugAssign extends Stmt {
  const AugAssign(super.line, this.target, this.op, this.value);
  final Expr target;
  final String op; // + - * / // % ** | & ^ << >>
  final Expr value;
}

class IfStmt extends Stmt {
  const IfStmt(super.line, this.test, this.body, this.orelse, this.elseLine);
  final Expr test;
  final List<Stmt> body;
  final List<Stmt> orelse; // an "elif" is an IfStmt inside orelse
  final int? elseLine; // line of the "else:" keyword (null if none)
}

class WhileStmt extends Stmt {
  const WhileStmt(super.line, this.test, this.body, this.orelse, this.elseLine);
  final Expr test;
  final List<Stmt> body;
  final List<Stmt> orelse;
  final int? elseLine;
}

class ForStmt extends Stmt {
  const ForStmt(
      super.line, this.target, this.iter, this.body, this.orelse, this.elseLine);
  final Expr target;
  final Expr iter;
  final List<Stmt> body;
  final List<Stmt> orelse;
  final int? elseLine;
}

class FuncDef extends Stmt {
  const FuncDef(
      super.line, this.name, this.params, this.defaults, this.body, this.decorators);
  final String name;
  final List<String> params;
  final List<Expr?> defaults; // same length as params (null = no default)
  final List<Stmt> body;
  final List<String> decorators; // for example staticmethod
}

class ClassDef extends Stmt {
  const ClassDef(super.line, this.name, this.bases, this.body);
  final String name;
  final List<Expr> bases;
  final List<Stmt> body;
}

class ExceptHandler {
  const ExceptHandler(this.line, this.type, this.name, this.body);
  final int line;
  final Expr? type; // null for a bare "except:"
  final String? name; // the "as e" name
  final List<Stmt> body;
}

class TryStmt extends Stmt {
  const TryStmt(super.line, this.body, this.handlers, this.orelse,
      this.finalbody, this.elseLine, this.finallyLine);
  final List<Stmt> body;
  final List<ExceptHandler> handlers;
  final List<Stmt> orelse;
  final List<Stmt> finalbody;
  final int? elseLine;
  final int? finallyLine;
}

class RaiseStmt extends Stmt {
  const RaiseStmt(super.line, this.exc);
  final Expr? exc;
}

class AssertStmt extends Stmt {
  const AssertStmt(super.line, this.test, this.msg);
  final Expr test;
  final Expr? msg;
}

class DelStmt extends Stmt {
  const DelStmt(super.line, this.targets);
  final List<Expr> targets;
}

/// import a, import a as b. Each item is [module, alias] (alias may be "").
class ImportStmt extends Stmt {
  const ImportStmt(super.line, this.items);
  final List<List<String>> items;
}

/// from a import b, c as d. Each item is [name, alias] (alias may be "").
class FromImportStmt extends Stmt {
  const FromImportStmt(super.line, this.module, this.items);
  final String module;
  final List<List<String>> items;
}

class GlobalStmt extends Stmt {
  const GlobalStmt(super.line, this.names);
  final List<String> names;
}

class ReturnStmt extends Stmt {
  const ReturnStmt(super.line, this.value);
  final Expr? value;
}

class BreakStmt extends Stmt {
  const BreakStmt(super.line);
}

class ContinueStmt extends Stmt {
  const ContinueStmt(super.line);
}

class PassStmt extends Stmt {
  const PassStmt(super.line);
}