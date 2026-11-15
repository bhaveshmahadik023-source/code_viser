import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/trace_models.dart';

/// State of the player: steps, current step, playing or not, speed.
class TracePlaybackState {
  const TracePlaybackState({
    required this.steps,
    required this.index,
    required this.playing,
    required this.speed,
  });

  factory TracePlaybackState.empty() =>
      const TracePlaybackState(steps: [], index: 0, playing: false, speed: 1);

  final List<TraceStep> steps;
  final int index; // current step (starts from 0)
  final bool playing; // true while auto play is running
  final double speed; // 0.5, 1, 1.5 or 2

  bool get isEmpty => steps.isEmpty;
  bool get isFirst => index == 0;
  bool get isLast => steps.isNotEmpty && index == steps.length - 1;

  TraceStep get current => steps[index];
  TraceStep? get previous => index > 0 ? steps[index - 1] : null;

  TracePlaybackState copyWith({int? index, bool? playing, double? speed}) {
    return TracePlaybackState(
      steps: steps,
      index: index ?? this.index,
      playing: playing ?? this.playing,
      speed: speed ?? this.speed,
    );
  }
}

/// Play, pause, next, previous, reset, seek and speed.
class TracePlaybackController extends Notifier<TracePlaybackState> {
  Timer? _timer;

  @override
  TracePlaybackState build() {
    ref.onDispose(() => _timer?.cancel());
    return TracePlaybackState.empty();
  }

  /// Loads new steps and goes to step 1.
  void load(List<TraceStep> steps) {
    _timer?.cancel();
    state = TracePlaybackState(
      steps: steps,
      index: 0,
      playing: false,
      speed: state.speed,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    final ms = (1100 / state.speed).round();
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (state.isLast) {
        pause();
      } else {
        state = state.copyWith(index: state.index + 1);
      }
    });
  }

  void play() {
    if (state.isEmpty) return;
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
    if (state.playing) _startTimer();
  }
}

final tracePlaybackProvider = NotifierProvider.autoDispose<
    TracePlaybackController, TracePlaybackState>(TracePlaybackController.new);