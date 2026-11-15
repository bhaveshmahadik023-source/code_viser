/// Error thrown while reading or running the user's code.
/// [line] is the 1-based line number (null if unknown).
class PyError implements Exception {
  PyError(this.line, this.message);

  final int? line;
  final String message;

  @override
  String toString() => line == null ? message : 'Line $line: $message';
}