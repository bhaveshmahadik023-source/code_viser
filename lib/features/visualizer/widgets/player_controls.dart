import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trace_playback_provider.dart';

/// Slider, play / pause, next, previous, reset and speed buttons.
class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(tracePlaybackProvider);
    final controller = ref.read(tracePlaybackProvider.notifier);

    if (playback.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Jump to any step.
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
    );
  }
}