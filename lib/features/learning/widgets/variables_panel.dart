import 'package:flutter/material.dart';

/// Shows all variables as small chips.
/// A chip gets a different color when its value just changed.
class VariablesPanel extends StatelessWidget {
  const VariablesPanel({super.key, required this.current, this.previous});

  /// Variables of the current step.
  final Map<String, String> current;

  /// Variables of the previous step (used to find what changed).
  final Map<String, String>? previous;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in current.entries)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              // Changed value gets a highlight color.
              color: previous?[entry.key] != entry.value
                  ? scheme.tertiaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.key} = ',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                // The value pops in when it changes.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    entry.value,
                    key: ValueKey('${entry.key}:${entry.value}'),
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