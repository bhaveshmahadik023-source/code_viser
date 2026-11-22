import 'package:flutter/material.dart';

import '../engine/trace_models.dart';

/// Shows how an if / elif / while / assert line decided:
/// the condition, its real values, True or False, and which way the
/// program goes next.
class DecisionCard extends StatelessWidget {
  const DecisionCard({super.key, required this.decision});

  final Decision decision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = decision.result;
    final color = ok ? Colors.green : Colors.redAccent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keyword and the condition as written.
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    decision.kind.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    decision.expression,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // The condition with real values and its result.
            Row(
              children: [
                Expanded(
                  child: Text(
                    decision.evaluated,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ok ? Icons.check_circle : Icons.cancel,
                          size: 18,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ok ? 'True' : 'False',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // The two ways the program can go. The chosen way lights up.
            Row(
              children: [
                Expanded(child: _path(context, decision.yesLabel, ok, true)),
                const SizedBox(width: 8),
                Expanded(child: _path(context, decision.noLabel, !ok, false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _path(BuildContext context, String label, bool taken, bool yes) {
    final scheme = Theme.of(context).colorScheme;
    final color = yes ? Colors.green : Colors.redAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: taken ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: taken ? color : scheme.outlineVariant,
          width: taken ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            taken ? Icons.arrow_forward_rounded : Icons.block_rounded,
            size: 18,
            color: taken ? color : scheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${yes ? 'True' : 'False'}: $label',
              style: TextStyle(
                fontSize: 13,
                fontWeight: taken ? FontWeight.bold : FontWeight.normal,
                color: taken ? scheme.onSurface : scheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}