/// How an array element was used in a step.
enum MarkKind {
  read, // element was read (for example in a comparison)
  write, // element was changed (for example in a swap)
}

/// How a variable should be drawn.
enum VarType {
  scalar, // number, text, bool, None
  list, // list, tuple or set
  matrix, // list of lists
  dict, // dictionary (key -> value)
  object, // instance of a class
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
    this.entries = const [],
    this.kind = 'list',
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

  /// For dictionaries and objects: key (or field name) and value text.
  final List<MapEntry<String, String>> entries;

  /// "list", "tuple" or "set" for lists. The class name for objects.
  final String kind;
}

/// The decision made by an if / elif / while / assert line.
class Decision {
  const Decision({
    required this.kind,
    required this.expression,
    required this.evaluated,
    required this.result,
    required this.yesLabel,
    required this.noLabel,
  });

  /// "if", "while" or "assert".
  final String kind;

  /// The condition as written, for example "arr[j] > arr[j + 1]".
  final String expression;

  /// The condition with real values, for example "5 > 3".
  final String evaluated;

  final bool result;

  /// What happens when the condition is True.
  final String yesLabel;

  /// What happens when the condition is False.
  final String noLabel;
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
    this.dictMarks = const {},
    this.skippedLines = const {},
    this.loops = const [],
    this.decision,
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

  /// Dictionary name -> (key text -> how the entry was used in this step).
  final Map<String, Map<String, MarkKind>> dictMarks;

  /// Source lines of branches that will NOT run (drawn faded).
  final Set<int> skippedLines;

  /// Active loops of the current frame, for example "for i: 2 of 5".
  final List<String> loops;

  /// Set for if / elif / while / assert lines.
  final Decision? decision;
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