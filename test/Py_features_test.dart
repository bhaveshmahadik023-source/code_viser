import 'package:codevisualizer/features/visualizer/engine/py_tracer.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> out(String code, {List<String> inputs = const []}) {
  final r = PyTracer(code, inputs: inputs).run();
  expect(r.error, isNull, reason: r.error?.message);
  return r.steps.last.output;
}

void main() {
  test('if / else shows a decision and fades the branch that will not run', () {
    const code = '''x = 5
if x > 3:
    print("big")
else:
    print("small")
''';
    final r = PyTracer(code).run();
    expect(r.error, isNull);
    final step = r.steps.firstWhere((s) => s.decision != null);
    expect(step.decision!.result, isTrue);
    expect(step.decision!.evaluated, '5 > 3');
    expect(step.skippedLines, containsAll([4, 5]));
    expect(r.steps.last.output, ['big']);
  });

  test('elif chain runs only the first true branch', () {
    const code = '''m = 72
if m >= 90:
    print("A")
elif m >= 60:
    print("C")
else:
    print("D")
''';
    expect(out(code), ['C']);
  });

  test('loops show their round counter', () {
    final r = PyTracer('for i in range(3):\n    pass\n').run();
    expect(r.steps.any((s) => s.loops.contains('for i: 2 of 3')), isTrue);
  });

  test('while with else and break', () {
    const code = '''i = 0
while i < 3:
    i += 1
else:
    print("no break")
''';
    expect(out(code), ['no break']);
  });

  test('f-strings with format specs', () {
    expect(out('x = 3.14159\nn = 7\nprint(f"{x:.2f} {n:03d} {n * 2}")\n'),
        ['3.14 007 14']);
  });

  test('print with sep and end', () {
    expect(out('print("a", end="")\nprint("b", "c", sep="-")\n'), ['ab-c']);
  });

  test('slicing', () {
    expect(
        out('a = [1, 2, 3, 4, 5]\nprint(a[1:4])\nprint(a[::-1])\nprint("hello"[1:3])\n'),
        ['[2, 3, 4]', '[5, 4, 3, 2, 1]', 'el']);
  });

  test('tuples, swap and sets', () {
    expect(out('a, b = 1, 2\na, b = b, a\nprint(a, b)\nprint((1, 2))\n'),
        ['2 1', '(1, 2)']);
    expect(out('s = {1, 2}\ns.add(3)\nprint(len(s))\nprint(2 in s)\n'),
        ['3', 'True']);
  });

  test('list and dict comprehensions', () {
    expect(out('print([n * n for n in range(7) if n % 2 == 0])\n'),
        ['[0, 4, 16, 36]']);
    expect(out('print({k: k * 2 for k in [1, 2]})\n'), ['{1: 2, 2: 4}']);
  });

  test('lambda, sorted with key, default and keyword arguments', () {
    expect(out('print(sorted([3, 1, 2], key=lambda x: -x))\n'), ['[3, 2, 1]']);
    expect(
        out('def f(a, b=2):\n    return a + b\nprint(f(1), f(1, b=5))\n'),
        ['3 6']);
  });

  test('input() reads the lines given', () {
    expect(
        out('name = input("Name: ")\nprint(name)\n', inputs: ['Asha']),
        ['Name: Asha', 'Asha']);
  });

  test('import math', () {
    expect(out('import math\nprint(math.sqrt(16))\nprint(math.floor(2.7))\n'),
        ['4.0', '2']);
  });

  test('classes, inheritance and super()', () {
    const code = '''class Animal:
    def __init__(self, name):
        self.name = name

    def speak(self):
        return "..."

class Dog(Animal):
    def __init__(self, name):
        super().__init__(name)
        self.tricks = 0

    def speak(self):
        return self.name + " says woof"

d = Dog("Rex")
print(d.speak())
print(isinstance(d, Animal))
''';
    expect(out(code), ['Rex says woof', 'True']);
    final r = PyTracer(code).run();
    final objectStep = r.steps.lastWhere((s) => s.vars.containsKey('d'));
    expect(objectStep.vars['d']!.entries.map((e) => e.key), ['name', 'tricks']);
  });

  test('try / except / finally and raise', () {
    const code = '''def divide(a, b):
    try:
        return a / b
    except ZeroDivisionError:
        return 0
    finally:
        print("done")

print(divide(10, 2))
print(divide(5, 0))
try:
    raise ValueError("bad")
except ValueError as e:
    print("caught", e)
''';
    expect(out(code), ['done', '5.0', 'done', '0', 'caught bad']);
  });

  test('an uncaught error is reported with its type', () {
    final r = PyTracer('x = [1]\nprint(x[5])\n').run();
    expect(r.error!.message, startsWith('IndexError'));
  });

  test('infinite recursion is stopped', () {
    final r = PyTracer('def f():\n    f()\nf()\n').run();
    expect(r.error!.message, contains('Recursion'));
  });
}