import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/trace_models.dart';

/// Draws one list.
/// Number lists are drawn as bars, other lists as boxes.
/// Bars grow, shrink and change color smoothly between steps.
class ArrayStrip extends StatelessWidget {
  const ArrayStrip({
    super.key,
    required this.snapshot,
    required this.marks,
    required this.pointers,
  });

  final VarSnapshot snapshot;

  /// Index -> how the element was used in this step (read / write).
  final Map<int, MarkKind> marks;

  /// Index -> pointer labels (for example "low" or "j, j+1").
  final Map<int, String> pointers;

  static const double _barMax = 130;
  static const double _barMin = 22;

  // Yellow = read / compared, red = changed, blue = normal.
  Color _colorFor(BuildContext context, MarkKind? mark) {
    final scheme = Theme.of(context).colorScheme;
    switch (mark) {
      case MarkKind.write:
        return Colors.redAccent;
      case MarkKind.read:
        return Colors.amber;
      case null:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = snapshot.items.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  snapshot.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Text('${snapshot.kind} with $n items',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            if (n == 0)
              Text('(empty list)', style: theme.textTheme.bodyMedium)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth =
                      math.min(60.0, math.max(30.0, constraints.maxWidth / n));
                  final row = Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < n; i++) _cell(context, i, cellWidth),
                    ],
                  );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: Center(child: row),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, int i, double width) {
    final theme = Theme.of(context);
    final mark = marks[i];
    final color = _colorFor(context, mark);
    final label = pointers[i] ?? '';
    final value = snapshot.items[i];
    final numbers = snapshot.numbers;

    final shadow = mark == null
        ? null
        : [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 12)];

    Widget body;
    if (numbers != null) {
      // Bar: height depends on the value.
      final maxAbs = numbers.fold<double>(1, (m, e) => math.max(m, e.abs()));
      final height = _barMin + (_barMax - _barMin) * (numbers[i].abs() / maxAbs);
      body = AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        width: width - 10,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: shadow,
        ),
      );
    } else {
      // Box with the value inside.
      body = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: width - 8,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          boxShadow: shadow,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.black87,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (numbers != null)
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 4),
          // A changed element grows a little.
          AnimatedScale(
            scale: mark == MarkKind.write ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: body,
          ),
          const SizedBox(height: 4),
          Text('$i', style: theme.textTheme.bodySmall),
          // Pointer label under the index.
          SizedBox(
            height: 28,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: label.isEmpty
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : _pointerChip(context, label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointerChip(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return FittedBox(
      key: ValueKey(label),
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '▲ $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}