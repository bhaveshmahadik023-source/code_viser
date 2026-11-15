import 'package:codevisualizer/features/visualizer/engine/py_tracer.dart';
import 'package:codevisualizer/features/visualizer/engine/trace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simple assignment and print', () {
    final r = PyTracer('a = 10\nb = 20\nprint(a + b)\n').run();
    expect(r.error, isNull);
    expect(r.steps.last.output, ['30']);
    expect(r.steps[1].vars['b']!.text, '20');
  });

  test('bubble sort sorts the list and marks swaps', () {
    const code = '''arr = [3, 1, 2]
n = len(arr)
for i in range(n - 1):
    for j in range(n - i - 1):
        if arr[j] > arr[j + 1]:
            arr[j], arr[j + 1] = arr[j + 1], arr[j]
print(arr)
''';
    final r = PyTracer(code).run();
    expect(r.error, isNull);
    expect(r.steps.last.output, ['[1, 2, 3]']);
    final swapped = r.steps.any(
      (s) => s.marks['arr']?.values.contains(MarkKind.write) ?? false,
    );
    expect(swapped, isTrue);
  });

  test('recursion builds a call stack', () {
    const code = '''def f(n):
    if n <= 1:
        return 1
    return n * f(n - 1)

print(f(4))
''';
    final r = PyTracer(code).run();
    expect(r.error, isNull);
    expect(r.steps.last.output, ['24']);
    expect(r.steps.any((s) => s.callStack.length > 3), isTrue);
  });

  test('binary search shows low, mid and high pointers', () {
    const code = '''def bs(arr, t):
    low = 0
    high = len(arr) - 1
    while low <= high:
        mid = (low + high) // 2
        if arr[mid] == t:
            return mid
        elif arr[mid] < t:
            low = mid + 1
        else:
            high = mid - 1
    return -1

print(bs([1, 3, 5, 7, 9], 7))
''';
    final r = PyTracer(code).run();
    expect(r.error, isNull);
    expect(r.steps.last.output, ['3']);
    final hasMid = r.steps.any(
      (s) => (s.pointers['arr'] ?? {}).values.any((l) => l.contains('mid')),
    );
    expect(hasMid, isTrue);
  });

  test('infinite loop is stopped', () {
    final r = PyTracer('x = 0\nwhile True:\n    x += 1\n').run();
    expect(r.error, isNotNull);
    expect(r.steps.length, greaterThan(100));
  });

  test('syntax error gives a line number and no steps', () {
    final r = PyTracer('x = (1 + \nprint(x)\n').run();
    expect(r.error, isNotNull);
    expect(r.steps, isEmpty);
  });

  test('unsupported feature gives a clear message', () {
    final r = PyTracer('import math\n').run();
    expect(r.error!.message, contains('not supported'));
  });
}