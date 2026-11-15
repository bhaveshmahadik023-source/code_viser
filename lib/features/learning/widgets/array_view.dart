import 'package:flutter/material.dart';

import '../engine/execution_step.dart';

/// Shows the array as bars.
/// When a value changes, the bar height and color change smoothly.
class ArrayView extends StatelessWidget {
  const ArrayView({super.key, required this.step});

  final ExecutionStep step;

  // Picks a color for a bar based on its mark.
  Color _color(BuildContext context, ArrayMark mark) {
    switch (mark) {
      case ArrayMark.compare:
        return Colors.amber;
      case ArrayMark.swap:
        return Colors.redAccent;
      case ArrayMark.sorted:
        return Colors.green;
      case ArrayMark.none:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Biggest value, used to scale all bar heights.
    final maxValue = step.array.fold<int>(1, (m, e) => e > m ? e : m);

    return SizedBox(
      height: 270,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < step.array.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Value on top of the bar.
                  Text(
                    '${step.array[i]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // The bar. AnimatedContainer makes the change smooth.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    width: 40,
                    height: 30 + 150 * step.array[i] / maxValue,
                    decoration: BoxDecoration(
                      color: _color(context, step.marks[i] ?? ArrayMark.none),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Index below the bar.
                  Text('$i', style: Theme.of(context).textTheme.bodySmall),
                  // Pointer names (like j, j+1) pointing to this index.
                  SizedBox(
                    height: 24,
                    child: Text(
                      step.pointers.entries
                          .where((e) => e.value == i)
                          .map((e) => e.key)
                          .join(', '),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}