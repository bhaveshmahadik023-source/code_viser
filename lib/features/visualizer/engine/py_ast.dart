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

class BinOp extends Expr {
  const BinOp(super.line, super.src, this.op, this.left, this.right);
  final String op; // + - * / // % **
  final Expr left;
  final Expr right;
}

class UnaryOp extends Expr {
  const UnaryOp(super.line, super.src, this.op, this.operand);
  final String op; // - + not
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
  final Expr index;
}

class Call extends Expr {
  const Call(super.line, super.src, this.func, this.args);
  final Expr func;
  final List<Expr> args;
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
  const Assign(super.line, this.target, this.value);
  final Expr target; // Name, Subscript or TupleLit
  final Expr value;
}

class AugAssign extends Stmt {
  const AugAssign(super.line, this.target, this.op, this.value);
  final Expr target;
  final String op; // + - * / // % **
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
  const WhileStmt(super.line, this.test, this.body);
  final Expr test;
  final List<Stmt> body;
}

class ForStmt extends Stmt {
  const ForStmt(super.line, this.target, this.iter, this.body);
  final Expr target;
  final Expr iter;
  final List<Stmt> body;
}

class FuncDef extends Stmt {
  const FuncDef(super.line, this.name, this.params, this.body);
  final String name;
  final List<String> params;
  final List<Stmt> body;
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