import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'execution_step.dart';

/// The state of the player: steps, current step, playing or not, speed.
class PlaybackState {
  const PlaybackState({
    required this.steps,
    required this.index,
    required this.playing,
    required this.speed,
  });

  /// Empty state used before any steps are loaded.
  factory PlaybackState.empty() =>
      const PlaybackState(steps: [], index: 0, playing: false, speed: 1);

  final List<ExecutionStep> steps;
  final int index; // current step position (starts from 0)
  final bool playing; // true when auto play is running
  final double speed; // 0.5, 1, 1.5 or 2

  bool get isEmpty => steps.isEmpty;
  bool get isFirst => index == 0;
  bool get isLast => steps.isNotEmpty && index == steps.length - 1;

  /// The step that is shown now.
  ExecutionStep get current => steps[index];

  /// The step before this one (null on the first step).
  ExecutionStep? get previous => index > 0 ? steps[index - 1] : null;

  PlaybackState copyWith({int? index, bool? playing, double? speed}) {
    return PlaybackState(
      steps: steps,
      index: index ?? this.index,
      playing: playing ?? this.playing,
      speed: speed ?? this.speed,
    );
  }
}

/// Controls play, pause, next, previous, reset and speed.
class PlaybackController extends Notifier<PlaybackState> {
  Timer? _timer;

  @override
  PlaybackState build() {
    // Stop the timer when this provider is removed.
    ref.onDispose(() => _timer?.cancel());
    return PlaybackState.empty();
  }

  /// Loads new steps and goes back to step 1.
  void load(List<ExecutionStep> steps) {
    _timer?.cancel();
    state = PlaybackState(
      steps: steps,
      index: 0,
      playing: false,
      speed: state.speed, // keep the chosen speed
    );
  }

  // Starts a timer that moves to the next step again and again.
  void _startTimer() {
    _timer?.cancel();
    final ms = (1000 / state.speed).round();
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (state.isLast) {
        pause(); // stop at the end
      } else {
        state = state.copyWith(index: state.index + 1);
      }
    });
  }

  void play() {
    if (state.isEmpty) return;
    // If we are at the end, start again from the beginning.
    if (state.isLast) state = state.copyWith(index: 0);
    state = state.copyWith(playing: true);
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(playing: false);
  }

  void toggle() => state.playing ? pause() : play();

  void next() {
    if (state.isEmpty || state.isLast) return;
    state = state.copyWith(index: state.index + 1);
  }

  void previous() {
    if (state.isEmpty || state.isFirst) return;
    state = state.copyWith(index: state.index - 1);
  }

  /// Jumps to any step (used by the slider).
  void seek(int i) {
    if (state.isEmpty) return;
    state = state.copyWith(index: i.clamp(0, state.steps.length - 1));
  }

  void reset() {
    _timer?.cancel();
    state = state.copyWith(index: 0, playing: false);
  }

  void setSpeed(double s) {
    state = state.copyWith(speed: s);
    // Restart the timer so the new speed is used.
    if (state.playing) _startTimer();
  }
}

/// Provider used by the screen. It is removed when the screen closes.
final playbackProvider =
    NotifierProvider.autoDispose<PlaybackController, PlaybackState>(
  PlaybackController.new,
);