import 'package:codevisualizer/features/visualizer/engine/py_tracer.dart';
import 'package:codevisualizer/features/visualizer/engine/trace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dictionary create, read, update and len', () {
    const code = '''d = {"a": 1}
d["b"] = 2
d["a"] = 5
print(d)
print(len(d))
print("b" in d)
''';
    final r = PyTracer(code).run();
    expect(r.error, isNull);
    expect(r.steps.last.output, ["{'a': 5, 'b': 2}", '2', 'True']);
  });

  test('character frequency with a dictionary', () {
    const code = '''count = {}
for ch in "banana":
    if ch in count:
        count[ch] += 1
    else:
        count[ch] = 1
print(count)
''';
    final r = PyTracer(code).run();
    expect(r.error, isNull);
    expect(r.steps.last.output, ["{'b': 1, 'a': 3, 'n': 2}"]);
    final hasWrite = r.steps.any(
      (s) => (s.dictMarks['count'] ?? {}).values.contains(MarkKind.write),
    );
    expect(hasWrite, isTrue);
  });

  test('get() with a default value', () {
    final r = PyTracer('d = {"x": 1}\nprint(d.get("y", 0))\n').run();
    expect(r.error, isNull);
    expect(r.steps.last.output, ['0']);
  });

  test('missing key gives a clear error', () {
    final r = PyTracer('d = {}\nprint(d["z"])\n').run();
    expect(r.error!.message, contains('not in the dictionary'));
  });

}