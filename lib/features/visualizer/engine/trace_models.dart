/// How an array element was used in a step.
enum MarkKind {
  read, // element was read (for example in a comparison)
  write, // element was changed (for example in a swap)
}

/// How a variable should be drawn.
enum VarType {
  scalar, // number, text, bool, None
  list, // 1D list
  matrix, // list of lists
}

/// A copy of one variable at one moment.
class VarSnapshot {
  const VarSnapshot({
    required this.name,
    required this.type,
    required this.text,
    this.items = const [],
    this.numbers,
    this.rows = const [],
  });

  final String name;
  final VarType type;

  /// Python-style text of the value, for example "[1, 2, 3]" or "5".
  final String text;

  /// For lists: text of every element.
  final List<String> items;

  /// For lists that only contain numbers: the numbers (used for bar heights).
  final List<double>? numbers;

  /// For matrices: text of every cell, row by row.
  final List<List<String>> rows;
}

/// One step of the dry run = a snapshot of the program at one moment.
class TraceStep {
  const TraceStep({
    required this.number,
    required this.line,
    required this.statement,
    required this.explanation,
    required this.vars,
    required this.marks,
    required this.pointers,
    required this.output,
    required this.callStack,
    this.condition,
  });

  /// Step number, starts from 1.
  final int number;

  /// Source line to highlight (1-based, 0 means no line).
  final int line;

  /// The code of the line that is running.
  final String statement;

  /// Simple sentence that explains what happened.
  final String explanation;

  /// Variables of the current function frame.
  final Map<String, VarSnapshot> vars;

  /// Array name -> (index -> how it was used in this step).
  final Map<String, Map<int, MarkKind>> marks;

  /// Array name -> (index -> pointer labels such as "j" or "low, mid").
  final Map<String, Map<int, String>> pointers;

  /// All lines printed so far.
  final List<String> output;

  /// Function calls that are active now (first = main program).
  final List<String> callStack;

  /// For if / while steps: result of the condition (null for other steps).
  final bool? condition;
}

/// Problem found while reading or running the code.
class TraceError {
  const TraceError(this.line, this.message);

  final int? line;
  final String message;
}

/// Result of running the code: all steps and an optional error.
class TraceResult {
  const TraceResult({required this.steps, this.error});

  final List<TraceStep> steps;
  final TraceError? error;
}