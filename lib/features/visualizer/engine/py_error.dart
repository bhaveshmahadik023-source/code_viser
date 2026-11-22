/// Error thrown while reading or running the user's code.
/// [line] is the 1-based line number (null if unknown).
class PyError implements Exception {
  PyError(
    this.line,
    this.message, {
    this.type,
    this.value,
    this.fatal = false,
  });

  final int? line;
  final String message;

  /// Python error type, for example "ValueError". Null = guess from message.
  final String? type;

  /// The exception object created by "raise" (if any).
  final Object? value;

  /// Limit errors (too many steps, too deep) cannot be caught by try/except.
  final bool fatal;

  @override
  String toString() => line == null ? message : 'Line $line: $message';
}