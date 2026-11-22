import 'package:flutter/material.dart';

import '../engine/trace_models.dart';

/// Draws a dictionary or an object as small cards: [ key | value ].
/// A read entry turns yellow. A new or changed entry turns red.
class DictView extends StatelessWidget {
  const DictView({
    super.key,
    required this.snapshot,
    this.marks = const <String, MarkKind>{},
    this.previous,
  });

  final VarSnapshot snapshot;

  /// Key text -> how the entry was used in this step.
  final Map<String, MarkKind> marks;

  /// The same variable in the previous step (to find changed entries).
  final VarSnapshot? previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = snapshot.entries;
    final isObject = snapshot.type == VarType.object;

    // Entries that are new or changed since the previous step.
    final before = <String, String>{
      for (final e in previous?.entries ?? const <MapEntry<String, String>>[])
        e.key: e.value,
    };

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
                Flexible(
                  child: Text(
                    isObject
                        ? 'object of class ${snapshot.kind}'
                        : 'dictionary with ${entries.length} entries',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Text(
                isObject ? '(no fields yet)' : '(empty dictionary)',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in entries)
                    _entryCard(
                      context,
                      entry,
                      marks[entry.key] ??
                          (previous != null && before[entry.key] != entry.value
                              ? MarkKind.write
                              : null),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(
    BuildContext context,
    MapEntry<String, String> entry,
    MarkKind? mark,
  ) {
    final scheme = Theme.of(context).colorScheme;

    Color color;
    switch (mark) {
      case MarkKind.write:
        color = Colors.redAccent;
        break;
      case MarkKind.read:
        color = Colors.amber;
        break;
      case null:
        color = scheme.primary;
        break;
    }

    final highlighted = mark != null;

    // The card pops a little when it is changed.
    return AnimatedScale(
      scale: mark == MarkKind.write ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: highlighted ? 2 : 1),
          color: color.withValues(alpha: highlighted ? 0.22 : 0.08),
          boxShadow: highlighted
              ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)]
              : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Key (or field name).
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(11),
                  ),
                ),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Value. It pops in when it changes.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    entry.value,
                    key: ValueKey('${entry.key}=${entry.value}'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}