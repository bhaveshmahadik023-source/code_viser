import 'package:flutter/material.dart';

/// Shows source code with line numbers.
/// The line that is running now gets a colored background.
class CodePanel extends StatelessWidget {
  const CodePanel({super.key, required this.code, required this.activeLine});

  final String code;

  /// Line to highlight (starts from 1).
  final int activeLine;

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        // Scroll sideways if a line is too long.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  // Highlight only the active line.
                  color: i + 1 == activeLine
                      ? scheme.primary.withValues(alpha: 0.25)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      // Line number.
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: scheme.outline,
                          ),
                        ),
                      ),
                      // Code text.
                      Text(
                        lines[i],
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}