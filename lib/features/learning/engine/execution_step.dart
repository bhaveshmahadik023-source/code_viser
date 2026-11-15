// Colors/marks that can be shown on an array element.
enum ArrayMark {
  none, // normal element
  compare, // two elements being compared
  swap, // two elements being swapped
  sorted, // element is in its final place
}

/// One step of the dry run.
/// It is a snapshot of the program at one moment.
class ExecutionStep {
  const ExecutionStep({
    required this.number,
    required this.javaLine,
    required this.pythonLine,
    required this.statement,
    required this.explanation,
    required this.variables,
    required this.array,
    required this.marks,
    required this.pointers,
    required this.output,
  });

  /// Step number, starts from 1.
  final int number;

  /// Line to highlight in the Java code (starts from 1).
  final int javaLine;

  /// Line to highlight in the Python code (starts from 1).
  final int pythonLine;

  /// The statement that is running, for example "j = 2".
  final String statement;

  /// Simple sentence that explains this step.
  final String explanation;

  /// Variable name -> value at this step.
  final Map<String, String> variables;

  /// Copy of the array at this step.
  final List<int> array;

  /// Array index -> mark (compare, swap, sorted).
  final Map<int, ArrayMark> marks;

  /// Pointer name -> array index, for example {'j': 2}.
  final Map<String, int> pointers;

  /// Output text printed so far (empty if nothing yet).
  final String output;
}

/// Every algorithm extends this class.
abstract class AlgorithmTracer {
  /// Name shown on the screen.
  String get name;

  /// Java source code to show.
  String get javaCode;

  /// Python source code to show.
  String get pythonCode;

  /// Runs the algorithm on the input and returns all steps.
  List<ExecutionStep> trace(List<int> input);
}