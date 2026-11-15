import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/execution_step.dart';
import '../engine/playback_controller.dart';
import '../widgets/array_view.dart';
import '../widgets/code_panel.dart';
import '../widgets/variables_panel.dart';

/// The main dry run screen.
/// It works for any algorithm, because the tracer is passed in.
class DryRunScreen extends ConsumerStatefulWidget {
  const DryRunScreen({super.key, required this.tracer});

  /// The algorithm to visualize.
  final AlgorithmTracer tracer;

  @override
  ConsumerState<DryRunScreen> createState() => _DryRunScreenState();
}

class _DryRunScreenState extends ConsumerState<DryRunScreen> {
  // Text box for the input array.
  final _input = TextEditingController(text: '5, 3, 8, 1, 2');

  // true = show Java code, false = show Python code.
  bool _showJava = true;

  AlgorithmTracer get _tracer => widget.tracer;

  @override
  void initState() {
    super.initState();
    // Load steps right after the first build.
    Future.microtask(_loadSteps);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  // Reads the input text, runs the algorithm and loads the steps.
  void _loadSteps() {
    if (!mounted) return;

    final numbers = _input.text
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();

    // Check the input is valid.
    if (numbers.length < 2 || numbers.length > 10 || numbers.any((n) => n < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter 2 to 10 positive numbers separated by commas.'),
        ),
      );
      return;
    }

    ref.read(playbackProvider.notifier).load(_tracer.trace(numbers));
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);

    // Show a loader until the steps are ready.
    if (playback.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_tracer.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final step = playback.current;
    final code = _showJava ? _tracer.javaCode : _tracer.pythonCode;
    final activeLine = _showJava ? step.javaLine : step.pythonLine;

    // Left side: input, array, explanation, variables, output.
    final leftSide = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input box and Apply button.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                decoration: const InputDecoration(
                  labelText: 'Input array (comma separated)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _loadSteps, child: const Text('Apply')),
          ],
        ),
        const SizedBox(height: 12),

        // Animated array bars.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ArrayView(step: step),
          ),
        ),
        const SizedBox(height: 12),

        // Step number, statement and explanation.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(step.number),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${step.number} / ${playback.steps.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
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
        ),
        const SizedBox(height: 12),

        // Variables.
        Text('Variables', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        VariablesPanel(
          current: step.variables,
          previous: playback.previous?.variables,
        ),
        const SizedBox(height: 12),

        // Output (only when there is some).
        if (step.output.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Output: ${step.output}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );

    // Right side: language switch, copy button and code.
    final rightSide = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Java')),
                ButtonSegment(value: false, label: Text('Python')),
              ],
              selected: {_showJava},
              onSelectionChanged: (s) => setState(() => _showJava = s.first),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Copy code',
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CodePanel(code: code, activeLine: activeLine),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text('${_tracer.name} - Dry Run')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Wide screen: two columns. Small screen: one column.
          final isWide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: leftSide),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: rightSide),
                    ],
                  )
                : Column(
                    children: [
                      leftSide,
                      const SizedBox(height: 16),
                      rightSide,
                    ],
                  ),
          );
        },
      ),

      // Controls at the bottom: slider, buttons and speed.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Slider to jump to any step.
              Slider(
                value: playback.index.toDouble(),
                min: 0,
                max: (playback.steps.length - 1).toDouble(),
                divisions:
                    playback.steps.length > 1 ? playback.steps.length - 1 : null,
                onChanged: (v) => controller.seek(v.round()),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  // Reset, previous, play/pause, next.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reset',
                        icon: const Icon(Icons.replay),
                        onPressed: controller.reset,
                      ),
                      IconButton(
                        tooltip: 'Previous step',
                        icon: const Icon(Icons.skip_previous),
                        onPressed: playback.isFirst ? null : controller.previous,
                      ),
                      IconButton.filled(
                        tooltip: playback.playing ? 'Pause' : 'Play',
                        icon: Icon(
                          playback.playing ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: controller.toggle,
                      ),
                      IconButton(
                        tooltip: 'Next step',
                        icon: const Icon(Icons.skip_next),
                        onPressed: playback.isLast ? null : controller.next,
                      ),
                    ],
                  ),
                  // Speed buttons.
                  SegmentedButton<double>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0.5, label: Text('0.5x')),
                      ButtonSegment(value: 1.0, label: Text('1x')),
                      ButtonSegment(value: 1.5, label: Text('1.5x')),
                      ButtonSegment(value: 2.0, label: Text('2x')),
                    ],
                    selected: {playback.speed},
                    onSelectionChanged: (s) => controller.setSpeed(s.first),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}