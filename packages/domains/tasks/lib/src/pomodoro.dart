/// A dependency-free Pomodoro state machine.
///
/// Pure Dart with no Flutter or drift dependency so the phase transitions are
/// unit-testable in isolation. The UI owns a `Timer.periodic` and calls [tick]
/// once per second; the engine owns *all* phase bookkeeping (round counting,
/// long-break cadence, focus/break alternation).
library;

/// The four phases a Pomodoro cycle moves through.
enum PomodoroPhase {
  focus,
  shortBreak,
  longBreak,
  finished;

  String get label => switch (this) {
        PomodoroPhase.focus => 'Focus',
        PomodoroPhase.shortBreak => 'Short break',
        PomodoroPhase.longBreak => 'Long break',
        PomodoroPhase.finished => 'Done',
      };

  bool get isBreak =>
      this == PomodoroPhase.shortBreak || this == PomodoroPhase.longBreak;
}

/// Tunable Pomodoro durations. Every value is floored at 1 minute on
/// construction so a bad config can never produce a zero-length phase.
class PomodoroConfig {
  const PomodoroConfig({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakEvery = 4,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  /// Number of focus rounds after which a [PomodoroPhase.longBreak] is taken
  /// instead of a short break.
  final int longBreakEvery;

  Duration get focusDuration => Duration(minutes: focusMinutes < 1 ? 1 : focusMinutes);
  Duration get shortBreakDuration =>
      Duration(minutes: shortBreakMinutes < 1 ? 1 : shortBreakMinutes);
  Duration get longBreakDuration =>
      Duration(minutes: longBreakMinutes < 1 ? 1 : longBreakMinutes);

  PomodoroConfig copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakEvery,
  }) {
    return PomodoroConfig(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      longBreakEvery: longBreakEvery ?? this.longBreakEvery,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PomodoroConfig &&
      other.focusMinutes == focusMinutes &&
      other.shortBreakMinutes == shortBreakMinutes &&
      other.longBreakMinutes == longBreakMinutes &&
      other.longBreakEvery == longBreakEvery;

  @override
  int get hashCode =>
      Object.hash(focusMinutes, shortBreakMinutes, longBreakMinutes, longBreakEvery);
}

/// An immutable snapshot of the engine.
class PomodoroState {
  const PomodoroState({
    required this.phase,
    required this.round,
    required this.remaining,
    required this.isRunning,
  });

  final PomodoroPhase phase;

  /// 1-based index of the current focus round.
  final int round;

  /// Time left in [phase].
  final Duration remaining;

  /// True between [PomodoroEngine.start] and the next [PomodoroEngine.pause].
  final bool isRunning;

  /// Fraction of [phase] already elapsed, 0.0..1.0. Used for the ring gauge.
  double progress(Duration total) {
    final totalMs = total.inMilliseconds;
    if (totalMs <= 0) return 1;
    final elapsed = totalMs - remaining.inMilliseconds;
    return (elapsed / totalMs).clamp(0.0, 1.0);
  }

  PomodoroState copyWith({
    PomodoroPhase? phase,
    int? round,
    Duration? remaining,
    bool? isRunning,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      round: round ?? this.round,
      remaining: remaining ?? this.remaining,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PomodoroState &&
      other.phase == phase &&
      other.round == round &&
      other.remaining == remaining &&
      other.isRunning == isRunning;

  @override
  int get hashCode => Object.hash(phase, round, remaining, isRunning);

  @override
  String toString() =>
      'PomodoroState(${phase.name}, round $round, ${remaining.inSeconds}s, '
      '${isRunning ? 'running' : 'paused'})';
}

/// Drives focus/break alternation and owns the round counter.
///
/// Lifecycle: construct (paused, full focus duration) -> [start] -> [tick]
/// per second -> auto-advances phase on expiry -> [PomodoroPhase.finished]
/// once the cycle is skipped past its final break.
class PomodoroEngine {
  PomodoroEngine({PomodoroConfig? config})
      : _config = config ?? const PomodoroConfig(),
        _remaining = (config ?? const PomodoroConfig()).focusDuration;

  final PomodoroConfig _config;

  PomodoroPhase _phase = PomodoroPhase.focus;
  int _round = 1;
  Duration _remaining;
  bool _isRunning = false;

  PomodoroConfig get config => _config;

  PomodoroState get state => PomodoroState(
        phase: _phase,
        round: _round,
        remaining: _remaining,
        isRunning: _isRunning,
      );

  /// Total length of the current phase, for [PomodoroState.progress].
  Duration get currentPhaseDuration => switch (_phase) {
        PomodoroPhase.focus => _config.focusDuration,
        PomodoroPhase.shortBreak => _config.shortBreakDuration,
        PomodoroPhase.longBreak => _config.longBreakDuration,
        PomodoroPhase.finished => Duration.zero,
      };

  /// True once the cycle has run to completion.
  bool get isFinished => _phase == PomodoroPhase.finished;

  void start() {
    if (isFinished) return;
    _isRunning = true;
  }

  void pause() => _isRunning = false;

  void toggle() => _isRunning ? pause() : start();

  /// Returns to a fresh, paused focus round.
  void reset() {
    _phase = PomodoroPhase.focus;
    _round = 1;
    _remaining = _config.focusDuration;
    _isRunning = false;
  }

  /// Advances one second. On expiry the phase transitions automatically and
  /// the new phase starts paused, so the user is never surprised by a break
  /// beginning without a visible tap. Returns the new state.
  ///
  /// Advancing past [PomodoroPhase.finished] is a no-op.
  PomodoroState tick([Duration step = const Duration(seconds: 1)]) {
    if (isFinished) return state;
    if (_isRunning && _remaining > Duration.zero) {
      _remaining -= step;
      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        _advance();
      }
    }
    return state;
  }

  /// Jumps to the next phase immediately (used by a "skip" affordance).
  PomodoroState skip() {
    if (isFinished) return state;
    _advance();
    return state;
  }

  void _advance() {
    switch (_phase) {
      case PomodoroPhase.focus:
        final isLongBreak = _round % (_config.longBreakEvery < 1 ? 1 : _config.longBreakEvery) == 0;
        _phase = isLongBreak ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
        _remaining =
            isLongBreak ? _config.longBreakDuration : _config.shortBreakDuration;
        break;
      case PomodoroPhase.shortBreak:
      case PomodoroPhase.longBreak:
        _round++;
        _phase = PomodoroPhase.focus;
        _remaining = _config.focusDuration;
        break;
      case PomodoroPhase.finished:
        break;
    }
    _isRunning = false;
  }
}
