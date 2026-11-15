import 'package:flutter/material.dart';

/// Black box that shows what the program printed.
class OutputConsole extends StatelessWidget {
  const OutputConsole({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(14),
      ),
      child: lines.isEmpty
          ? const Text(
              '(nothing printed yet)',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.white38,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++)
                  Text(
                    '> ${lines[i]}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      // The newest line is brighter.
                      color: i == lines.length - 1
                          ? const Color(0xFF67E8F9)
                          : Colors.white70,
                    ),
                  ),
              ],
            ),
    );
  }
}