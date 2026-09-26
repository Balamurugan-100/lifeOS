import 'package:drift/drift.dart' show Value;
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:test/test.dart';

/// Covers tracked-work bookkeeping: the "one running session" invariant,
/// start/stop materialization, and the aggregate totals the task list and the
/// home summary read.
void main() {
  late TaskDatabase database;
  late TaskRepository tasks;
  late TimeRepository time;

  /// A fixed local "now" so totals that derive from wall-clock elapsed time are
  /// deterministic. All fixtures are stamped relative to it.
  final now = DateTime.utc(2026, 9, 22, 15, 0);

  setUp(() {
    database = TaskDatabase(openInMemoryExecutor());
    tasks = TaskRepository(database);
    time = TimeRepository(database);
  });

  tearDown(() => database.close());

  /// Inserts a *closed* session directly so totals can be asserted without
  /// sleeping through a real timer.
  Future<TimeSession> seedSession(
    String taskId, {
    required DateTime startedAt,
    required int seconds,
    bool isPomodoro = false,
    String? label,
  }) async {
    final id = 'seed-${startedAt.microsecondsSinceEpoch}-$seconds';
    await database.into(database.timeSessions).insert(
          TimeSessionsCompanion.insert(
            id: id,
            taskId: taskId,
            startedAt: startedAt,
            endedAt: Value(startedAt.add(Duration(seconds: seconds))),
            durationSeconds: Value(seconds),
            isPomodoro: Value(isPomodoro),
            label: Value(label),
            createdAt: startedAt,
            updatedAt: startedAt,
          ),
        );
    return (await time.byId(id))!;
  }

  group('startSession', () {
    test('opens a running session that reports as in flight', () async {
      final task = await tasks.add('Write the report');

      final session = await time.startSession(task.id);

      expect(session.taskId, task.id);
      expect(session.isRunning, isTrue);
      expect(session.endedAt, isNull);
      expect(session.durationSeconds, 0);
      expect(session.isPomodoro, isFalse);
      expect(await time.isTracking(task.id), isTrue);
      expect((await time.activeSession())?.id, session.id);
    });

    test('records the pomodoro flag and a trimmed label', () async {
      final task = await tasks.add('Deep work');

      final session =
          await time.startSession(task.id, isPomodoro: true, label: '  Sprint 1  ');

      expect(session.isPomodoro, isTrue);
      expect(session.label, 'Sprint 1');
      expect((await time.byId(session.id))?.label, 'Sprint 1');
    });

    test('a blank label is stored as null', () async {
      final task = await tasks.add('Deep work');
      final session = await time.startSession(task.id, label: '   ');

      expect(session.label, isNull);
      expect((await time.byId(session.id))?.label, isNull);
    });

    test('is idempotent for the same task', () async {
      final task = await tasks.add('Write the report');

      final first = await time.startSession(task.id);
      final second = await time.startSession(task.id);

      expect(second.id, first.id);
      expect(await time.allTimeSessions(), hasLength(1));
    });

    test('stopping the previous task enforces a single running session',
        () async {
      final first = await tasks.add('Task A');
      final second = await tasks.add('Task B');

      final a = await time.startSession(first.id);
      await time.startSession(second.id);

      final closedA = await time.byId(a.id);
      expect(closedA?.isRunning, isFalse,
          reason: 'switching tasks must close the old session');
      expect(closedA?.endedAt, isNotNull);
      expect(await time.isTracking(first.id), isFalse);
      expect(await time.isTracking(second.id), isTrue);
    });
  });

  group('stopSession', () {
    test('materializes elapsed seconds and clears the running flag', () async {
      final task = await tasks.add('Write the report');
      final session = await time.startSession(task.id);

      // Backdate the start so the materialized duration is predictable.
      final started = now.subtract(const Duration(minutes: 30));
      await (database.update(database.timeSessions)
            ..where((s) => s.id.equals(session.id)))
          .write(TimeSessionsCompanion(startedAt: Value(started)));

      final stopped = await time.stopSession(session.id);

      expect(stopped, isNotNull);
      expect(stopped!.isRunning, isFalse);
      expect(stopped.durationSeconds, greaterThanOrEqualTo(29 * 60));
      expect(stopped.endedAt, isNotNull);
      expect(await time.activeSession(), isNull);
      expect((await time.byId(session.id))?.durationSeconds, stopped.durationSeconds);
    });

    test('returns null for an unknown id and is a no-op when already stopped',
        () async {
      final task = await tasks.add('Write the report');
      final session = await time.startSession(task.id);

      expect(await time.stopSession('nope'), isNull);
      await time.stopSession(session.id);
      expect(await time.stopSession(session.id), isNull);
    });

    test('stopActiveSession stops whatever is running, or nothing', () async {
      final task = await tasks.add('Write the report');
      expect(await time.stopActiveSession(), isNull);

      final session = await time.startSession(task.id);
      final stopped = await time.stopActiveSession();

      expect(stopped?.id, session.id);
      expect(await time.stopActiveSession(), isNull);
    });
  });

  group('lookup', () {
    test('activeSessionFor only matches the requested task', () async {
      final a = await tasks.add('A');
      final b = await tasks.add('B');
      await time.startSession(a.id);

      expect((await time.activeSessionFor(a.id))?.taskId, a.id);
      expect(await time.activeSessionFor(b.id), isNull);
    });

    test('sessionsForTask is newest first and honours limit', () async {
      final task = await tasks.add('A');
      await seedSession(task.id, startedAt: now, seconds: 60);
      await seedSession(task.id, startedAt: now.subtract(const Duration(hours: 1)), seconds: 30);
      await seedSession(task.id, startedAt: now.subtract(const Duration(hours: 2)), seconds: 10);

      final all = await time.sessionsForTask(task.id);
      expect(all.map((s) => s.durationSeconds).toList(), [60, 30, 10]);

      final limited = await time.sessionsForTask(task.id, limit: 2);
      expect(limited, hasLength(2));
    });

    test('deleteSession removes a session from the active list and totals',
        () async {
      final task = await tasks.add('A');
      final session =
          await seedSession(task.id, startedAt: now, seconds: 600);

      expect(await time.totalSecondsForTask(task.id), 600);

      await time.deleteSession(session.id);

      expect(await time.totalSecondsForTask(task.id), 0);
      expect(await time.sessionsForTask(task.id), isEmpty);
      expect(await time.allTimeSessions(), isEmpty);
    });
  });

  group('totals', () {
    test('sums every session for a task', () async {
      final task = await tasks.add('A');
      await seedSession(task.id, startedAt: now, seconds: 600);
      await seedSession(task.id, startedAt: now.subtract(const Duration(days: 1)), seconds: 900);

      expect(await time.totalSecondsForTask(task.id), 1500);
    });

    test('a running session contributes live elapsed time as of now', () async {
      final task = await tasks.add('A');
      final session = await time.startSession(task.id);
      await (database.update(database.timeSessions)
            ..where((s) => s.id.equals(session.id)))
          .write(TimeSessionsCompanion(
              startedAt: Value(now.subtract(const Duration(minutes: 5)))));

      expect(
        await time.totalSecondsForTask(task.id, now: now),
        300,
        reason: 'a running session ticks up live, not just after it stops',
      );
    });

    test('since filters out sessions started before the cutoff', () async {
      final task = await tasks.add('A');
      await seedSession(task.id, startedAt: now, seconds: 600);
      await seedSession(task.id, startedAt: now.subtract(const Duration(days: 3)), seconds: 900);

      final cutoff = now.subtract(const Duration(days: 1));
      expect(await time.totalSecondsForTaskSince(task.id, cutoff, now: now), 600);
      expect(await time.totalSecondsForTask(task.id, since: cutoff, now: now), 600);
    });

    test('totalsByTask groups in one pass and omits untouched tasks', () async {
      final a = await tasks.add('A');
      final b = await tasks.add('B');
      final c = await tasks.add('C');
      await seedSession(a.id, startedAt: now, seconds: 60);
      await seedSession(a.id, startedAt: now.subtract(const Duration(hours: 1)), seconds: 30);
      await seedSession(b.id, startedAt: now, seconds: 90);

      final totals = await time.totalsByTask(now: now);

      expect(totals, {a.id: 90, b.id: 90});
      expect(totals.containsKey(c.id), isFalse);
    });
  });

  group('daily totals', () {
    test('totalSecondsForDay only counts that local calendar day', () async {
      final task = await tasks.add('A');
      await seedSession(task.id, startedAt: now, seconds: 600);
      await seedSession(task.id, startedAt: now.subtract(const Duration(days: 1)), seconds: 900);

      expect(await time.totalSecondsForDay(now, now: now), 600);
      expect(await time.totalSecondsForDay(now.subtract(const Duration(days: 1)), now: now), 900);
    });

    test('totalSecondsForToday defaults to the current day', () async {
      final task = await tasks.add('A');
      final today = DateTime.now();
      await seedSession(task.id, startedAt: today.toUtc(), seconds: 300);

      expect(await time.totalSecondsForToday(), 300);
    });

    test('dailyTotals returns one zero-filled bucket per day, oldest first',
        () async {
      final task = await tasks.add('A');
      final anchor = DateTime(2026, 9, 22, 12);
      await seedSession(task.id, startedAt: DateTime.utc(2026, 9, 22, 9), seconds: 600);
      await seedSession(task.id, startedAt: DateTime.utc(2026, 9, 20, 9), seconds: 300);
      // Outside the window — must not leak in.
      await seedSession(task.id, startedAt: DateTime.utc(2026, 9, 1, 9), seconds: 999);

      final totals = await time.dailyTotals(days: 5, today: anchor);

      expect(totals.keys.toList(), [
        '2026-09-18',
        '2026-09-19',
        '2026-09-20',
        '2026-09-21',
        '2026-09-22',
      ]);
      expect(totals['2026-09-20'], 300);
      expect(totals['2026-09-22'], 600);
      expect(totals['2026-09-19'], 0);
    });

    test('dailyTotals counts a running session as live elapsed', () async {
      final task = await tasks.add('A');
      final session = await time.startSession(task.id);
      await (database.update(database.timeSessions)
            ..where((s) => s.id.equals(session.id)))
          .write(TimeSessionsCompanion(
              startedAt: Value(now.subtract(const Duration(minutes: 2)))));

      final totals = await time.dailyTotals(days: 1, today: now, now: now);
      expect(totals['2026-09-22'], greaterThanOrEqualTo(120));
    });
  });

  group('soft-deleted tasks', () {
    test('sessions survive a deleted task so history is not lost', () async {
      final task = await tasks.add('Doomed');
      final session = await time.startSession(task.id);
      await time.stopSession(session.id);

      await tasks.delete(task.id);

      final remaining = await time.sessionsForTask(task.id);
      expect(remaining, hasLength(1));
      expect(await time.totalSecondsForTask(task.id), greaterThanOrEqualTo(0));
    });
  });
}
