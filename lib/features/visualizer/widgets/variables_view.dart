import 'package:flutter/material.dart';

import '../engine/trace_models.dart';

/// Shows number / text variables as small chips.
/// A chip lights up when its value is new or just changed.
class VariablesView extends StatelessWidget {
  const VariablesView({super.key, required this.current, this.previous});

  final Map<String, VarSnapshot> current;
  final Map<String, VarSnapshot>? previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scalars =
        current.values.where((v) => v.type == VarType.scalar).toList();

    if (scalars.isEmpty) {
      return Text(
        'No variables yet',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in scalars)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: previous?[v.name]?.text != v.text
                  ? scheme.tertiaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${v.name} = ',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                // The value pops in when it changes.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    v.text,
                    key: ValueKey('${v.name}:${v.text}'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}