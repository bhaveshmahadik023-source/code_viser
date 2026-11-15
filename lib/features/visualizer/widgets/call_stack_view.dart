import 'package:flutter/material.dart';

/// Shows the active function calls. The newest call is on top.
class CallStackView extends StatelessWidget {
  const CallStackView({super.key, required this.stack});

  final List<String> stack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reversed = stack.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < reversed.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: i == 0
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: i == 0 ? scheme.primary : Colors.transparent,
              ),
            ),
            child: Text(
              reversed[i],
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }
}