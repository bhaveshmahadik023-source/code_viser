import 'package:flutter/material.dart';

import '../engine/trace_models.dart';

/// Shows the current step: statement, explanation and condition result.
class StepCard extends StatelessWidget {
  const StepCard({super.key, required this.step, required this.total});

  final TraceStep step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cond = step.condition;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // The text fades when the step changes.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(step.number),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Step ${step.number} of $total',
                    style: theme.textTheme.labelLarge,
                  ),
                  const Spacer(),
                  if (cond != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (cond ? Colors.green : Colors.redAccent)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cond ? 'True ✓' : 'False ✗',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cond ? Colors.green : Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (step.statement.isNotEmpty)
                Text(
                  step.statement,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 6),
              Text(step.explanation),
            ],
          ),
        ),
      ),
    );
  }
}