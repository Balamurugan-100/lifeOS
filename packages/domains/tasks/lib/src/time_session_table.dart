import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;

import 'task_table.dart';

/// Drift table backing a tracked block of work against a [Tasks] row.
///
/// A session is *running* while `ended_at` is null; `duration_seconds` is
/// materialized at stop time (0 while running). `is_pomodoro` distinguishes a
/// Pomodoro round from an open-ended stopwatch session, and `label` carries an
/// optional free-form note ("deep work", "Pomodoro 3"). Audit fields are UTC.
class TimeSessions extends Table with AuditFields {
  TextColumn get id => text()();

  /// Owning task. Sessions survive a soft-deleted task so tracked time is
  /// never silently lost.
  TextColumn get taskId => text().named('task_id').references(Tasks, #id)();

  /// Session start instant, UTC.
  DateTimeColumn get startedAt => dateTime().named('started_at')();

  /// Session end instant, UTC; null while the session is still running.
  DateTimeColumn get endedAt => dateTime().nullable().named('ended_at')();

  /// Materialized elapsed seconds; 0 while running (use `elapsedAt` instead).
  IntColumn get durationSeconds =>
      integer().withDefault(const Constant(0)).named('duration_seconds')();

  /// True when the session was started as a Pomodoro round.
  BoolColumn get isPomodoro =>
      boolean().withDefault(const Constant(false)).named('is_pomodoro')();

  /// Optional session label removed.

  @override
  Set<Column> get primaryKey => {id};
}
