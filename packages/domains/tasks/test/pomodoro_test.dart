import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:test/test.dart';

/// Exercises the Pomodoro state machine in isolation — it is pure Dart with no
/// clock of its own, so tests drive it with explicit [PomodoroEngine.tick]
/// steps and assert the observable phase/round/remaining triple.
void main() {
  /// A config with tiny durations keeps the tests readable while still
  /// covering the same transitions the UI drives at 25/5/15 minutes.
  const config = PomodoroConfig(
    focusMinutes: 2,
    shortBreakMinutes: 1,
    longBreakMinutes: 3,
    longBreakEvery: 2,
  );

  PomodoroEngine newEngine([PomodoroConfig c = config]) =>
      PomodoroEngine(config: c);

  group('PomodoroPhase', () {
    test('labels every phase', () {
      expect(PomodoroPhase.focus.label, 'Focus');
      expect(PomodoroPhase.shortBreak.label, 'Short break');
      expect(PomodoroPhase.longBreak.label, 'Long break');
      expect(PomodoroPhase.finished.label, 'Done');
    });

    test('only short and long breaks are breaks', () {
      expect(PomodoroPhase.focus.isBreak, isFalse);
      expect(PomodoroPhase.shortBreak.isBreak, isTrue);
      expect(PomodoroPhase.longBreak.isBreak, isTrue);
      expect(PomodoroPhase.finished.isBreak, isFalse);
    });
  });

  group('PomodoroConfig', () {
    test('defaults to the classic 25/5/15 with a long break every 4', () {
      const c = PomodoroConfig();
      expect(c.focusDuration, const Duration(minutes: 25));
      expect(c.shortBreakDuration, const Duration(minutes: 5));
      expect(c.longBreakDuration, const Duration(minutes: 15));
      expect(c.longBreakEvery, 4);
    });

    test('floors every duration at one minute so a phase is never zero', () {
      const c = PomodoroConfig(
        focusMinutes: 0,
        shortBreakMinutes: -5,
        longBreakMinutes: 0,
      );
      expect(c.focusDuration, const Duration(minutes: 1));
      expect(c.shortBreakDuration, const Duration(minutes: 1));
      expect(c.longBreakDuration, const Duration(minutes: 1));
    });

    test('copyWith replaces only the named fields and keeps value equality', () {
      const c = PomodoroConfig();
      final tweaked = c.copyWith(focusMinutes: 50);

      expect(tweaked.focusMinutes, 50);
      expect(tweaked.shortBreakMinutes, c.shortBreakMinutes);
      expect(tweaked, isNot(c));
      expect(tweaked, c.copyWith(focusMinutes: 50));
      expect(tweaked.hashCode, c.copyWith(focusMinutes: 50).hashCode);
    });
  });

  group('PomodoroState.progress', () {
    test('is 0.0 at the start and 1.0 at the end of a phase', () {
      const state = PomodoroState(
        phase: PomodoroPhase.focus,
        round: 1,
        remaining: Duration(minutes: 25),
        isRunning: true,
      );
      expect(state.progress(const Duration(minutes: 25)), 0.0);
      expect(
        state.copyWith(remaining: const Duration(seconds: 1))
            .progress(const Duration(minutes: 25)),
        closeTo(0.999, 0.001),
      );
    });

    test('clamps out-of-range remaining values', () {
      const over = PomodoroState(
        phase: PomodoroPhase.focus,
        round: 1,
        remaining: Duration(minutes: 30),
        isRunning: true,
      );
      expect(over.progress(const Duration(minutes: 25)), 0.0);

      const under = PomodoroState(
        phase: PomodoroPhase.focus,
        round: 1,
        remaining: Duration.zero,
        isRunning: true,
      );
      expect(under.progress(const Duration(minutes: 25)), 1.0);
    });

    test('treats a non-positive total as complete', () {
      const state = PomodoroState(
        phase: PomodoroPhase.finished,
        round: 1,
        remaining: Duration.zero,
        isRunning: false,
      );
      expect(state.progress(Duration.zero), 1.0);
    });
  });

  group('PomodoroEngine lifecycle', () {
    test('starts paused on round 1 with a full focus phase', () {
      final engine = newEngine();
      final state = engine.state;

      expect(state.phase, PomodoroPhase.focus);
      expect(state.round, 1);
      expect(state.remaining, config.focusDuration);
      expect(state.isRunning, isFalse);
      expect(engine.isFinished, isFalse);
      expect(engine.currentPhaseDuration, config.focusDuration);
    });

    test('start/pause/toggle flip isRunning', () {
      final engine = newEngine()..start();
      expect(engine.state.isRunning, isTrue);

      engine.pause();
      expect(engine.state.isRunning, isFalse);

      engine.toggle();
      expect(engine.state.isRunning, isTrue);
      engine.toggle();
      expect(engine.state.isRunning, isFalse);
    });

    test('a paused engine does not consume ticks', () {
      final engine = newEngine();
      engine.tick(const Duration(minutes: 1));
      engine.tick(const Duration(minutes: 1));

      expect(engine.state.remaining, config.focusDuration);
    });

    test('reset returns to a fresh paused focus round', () {
      final engine = newEngine()..start();
      engine.tick(const Duration(minutes: 2));
      expect(engine.state.phase, PomodoroPhase.shortBreak);

      engine.reset();

      expect(engine.state.phase, PomodoroPhase.focus);
      expect(engine.state.round, 1);
      expect(engine.state.remaining, config.focusDuration);
      expect(engine.state.isRunning, isFalse);
    });
  });

  group('PomodoroEngine phase advancement', () {
    test('focus expires into a short break, left paused', () {
      final engine = newEngine()..start();
      engine.tick(const Duration(minutes: 1, seconds: 59));
      expect(engine.state.phase, PomodoroPhase.focus);

      final state = engine.tick(const Duration(seconds: 1));

      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.remaining, config.shortBreakDuration);
      expect(state.isRunning, isFalse,
          reason: 'a new phase must never auto-start');
    });

    test('a short break returns to focus and increments the round', () {
      final engine = newEngine()..start();
      engine.skip(); // focus -> short break
      expect(engine.state.phase, PomodoroPhase.shortBreak);
      expect(engine.state.round, 1);

      final state = engine.skip(); // short break -> focus

      expect(state.phase, PomodoroPhase.focus);
      expect(state.round, 2);
      expect(state.remaining, config.focusDuration);
    });

    test('every longBreakEvery-th round earns a long break', () {
      final engine = newEngine();
      final seen = <PomodoroPhase>[];

      // Walk 4 full focus phases and record the break that followed each.
      for (var i = 0; i < 4; i++) {
        engine.start();
        engine.tick(config.focusDuration);
        seen.add(engine.state.phase);
        engine.skip(); // consume the break, back to focus
      }

      expect(seen, [
        PomodoroPhase.shortBreak, // round 1
        PomodoroPhase.longBreak, // round 2
        PomodoroPhase.shortBreak, // round 3
        PomodoroPhase.longBreak, // round 4
      ]);
      expect(engine.state.round, 5);
    });

    test('currentPhaseDuration tracks the active phase', () {
      final engine = newEngine()..start();

      expect(engine.currentPhaseDuration, config.focusDuration);
      engine.tick(config.focusDuration);
      expect(engine.currentPhaseDuration, config.shortBreakDuration);

      // A new phase always starts paused, so it must be re-started to burn down.
      engine.skip();
      expect(engine.currentPhaseDuration, config.focusDuration);
      engine.start();
      engine.tick(config.focusDuration);
      expect(engine.currentPhaseDuration, config.longBreakDuration);
    });

    test('skip jumps to the next phase without waiting', () {
      final engine = newEngine()..start();
      final state = engine.skip();

      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.remaining, config.shortBreakDuration);
    });

    test('a single oversized tick still advances only one phase', () {
      final engine = newEngine()..start();
      final state = engine.tick(const Duration(hours: 1));

      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.remaining, config.shortBreakDuration);
    });
  });

  group('PomodoroConfig.longBreakEvery guard', () {
    test('a value below 1 degrades to a long break every round instead of '
        'dividing by zero', () {
      final engine = newEngine(
        const PomodoroConfig(
          focusMinutes: 1,
          shortBreakMinutes: 1,
          longBreakMinutes: 1,
          longBreakEvery: 0,
        ),
      )..start();

      final state = engine.tick(const Duration(minutes: 1));
      expect(state.phase, PomodoroPhase.longBreak);
    });
  });

  group('state value semantics', () {
    test('identical snapshots compare equal and hash alike', () {
      final a = newEngine().state;
      final b = newEngine().state;
      final running = newEngine()..start();

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(running.state));
    });

    test('toString names the phase, round and run state', () {
      final text = newEngine().state.toString();
      expect(text, contains('focus'));
      expect(text, contains('round 1'));
      expect(text, contains('paused'));
    });
  });
}
