import 'execution_step.dart';

/// Creates dry run steps for Bubble Sort.
/// The algorithm really runs here, so the steps are real (not fake).
class BubbleSortTracer extends AlgorithmTracer {
  @override
  String get name => 'Bubble Sort';

  // Line numbers below must match the highlighted lines in trace().
  @override
  String get javaCode => '''int n = arr.length;
for (int i = 0; i < n - 1; i++) {
    for (int j = 0; j < n - i - 1; j++) {
        if (arr[j] > arr[j + 1]) {
            int t = arr[j];
            arr[j] = arr[j + 1];
            arr[j + 1] = t;
        }
    }
}''';

  @override
  String get pythonCode => '''n = len(arr)
for i in range(n - 1):
    for j in range(n - i - 1):
        if arr[j] > arr[j + 1]:
            arr[j], arr[j + 1] = arr[j + 1], arr[j]''';

  @override
  List<ExecutionStep> trace(List<int> input) {
    // Work on a copy so the original input is not changed.
    final a = List<int>.of(input);
    final n = a.length;
    final steps = <ExecutionStep>[];

    // Marks every index from [sortedFrom] to the end as sorted.
    // [extra] adds more marks, like compare or swap.
    Map<int, ArrayMark> marks(int sortedFrom,
            [Map<int, ArrayMark> extra = const {}]) =>
        {
          for (var k = sortedFrom; k < n; k++) k: ArrayMark.sorted,
          ...extra,
        };

    // Saves one step. It also copies the current array.
    void add({
      required int line,
      required String statement,
      required String explanation,
      required Map<String, String> vars,
      required Map<int, ArrayMark> marks,
      Map<String, int> pointers = const {},
      String output = '',
    }) {
      steps.add(ExecutionStep(
        number: steps.length + 1,
        javaLine: line,
        pythonLine: line, // same line numbers in both languages here
        statement: statement,
        explanation: explanation,
        variables: vars,
        array: List<int>.of(a),
        marks: marks,
        pointers: pointers,
        output: output,
      ));
    }

    // Line 1: store the array length.
    add(
      line: 1,
      statement: 'n = $n',
      explanation: 'The array has $n elements, so n = $n.',
      vars: {'n': '$n'},
      marks: marks(n),
    );

    // Outer loop: each pass moves the biggest element to the end.
    for (var i = 0; i < n - 1; i++) {
      add(
        line: 2,
        statement: 'i = $i',
        explanation:
            'Pass ${i + 1} starts. After this pass the biggest element goes to the end.',
        vars: {'n': '$n', 'i': '$i'},
        marks: marks(n - i),
      );

      // Inner loop: compare neighbours.
      for (var j = 0; j < n - i - 1; j++) {
        final vars = {'n': '$n', 'i': '$i', 'j': '$j'};
        final pointers = {'j': j, 'j+1': j + 1};
        final sortedFrom = n - i;

        // Line 3: inner loop check.
        add(
          line: 3,
          statement: 'j = $j',
          explanation: 'Inner loop runs with j = $j because $j < ${n - i - 1}.',
          vars: vars,
          marks: marks(sortedFrom),
          pointers: pointers,
        );

        // Line 4: compare two neighbours.
        final needSwap = a[j] > a[j + 1];
        add(
          line: 4,
          statement: 'if (arr[$j] > arr[${j + 1}])',
          explanation:
              'Is ${a[j]} > ${a[j + 1]}? ${needSwap ? "Yes, so we swap them." : "No, so we do nothing."}',
          vars: vars,
          marks: marks(sortedFrom, {
            j: ArrayMark.compare,
            j + 1: ArrayMark.compare,
          }),
          pointers: pointers,
        );

        // Line 5: swap if the left one is bigger.
        if (needSwap) {
          final t = a[j];
          a[j] = a[j + 1];
          a[j + 1] = t;
          add(
            line: 5,
            statement: 'swap(arr[$j], arr[${j + 1}])',
            explanation: 'The two elements are swapped. Array: ${a.join(", ")}',
            vars: {...vars, 't': '$t'},
            marks: marks(sortedFrom, {
              j: ArrayMark.swap,
              j + 1: ArrayMark.swap,
            }),
            pointers: pointers,
          );
        }
      }

      // End of one pass: the last unsorted element is now in place.
      add(
        line: 2,
        statement: 'pass ${i + 1} finished',
        explanation: '${a[n - i - 1]} is now in its correct place (sorted).',
        vars: {'n': '$n', 'i': '$i'},
        marks: marks(n - i - 1),
      );
    }

    // Final step: everything is sorted, show the output.
    add(
      line: 2,
      statement: 'loop finished',
      explanation: 'All passes are done. The array is sorted.',
      vars: {'n': '$n'},
      marks: marks(0),
      output: 'Sorted: [${a.join(", ")}]',
    );

    return steps;
  }
}