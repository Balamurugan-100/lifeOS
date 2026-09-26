import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart' show calendarDate, newId;
import 'package:lifeos_storage/lifeos_storage.dart' show utcNow;

import 'task_database.dart' hide TimeSession;
import 'time_session.dart';

/// Repository over tracked work sessions.
///
/// Invariant: **at most one running session exists at a time.** The user cannot
/// be working on two tasks simultaneously, so [startSession] first stops any
/// session already in flight (materializing its duration) before opening the
/// new one. That keeps "total time per task" additive and non-overlapping.
class TimeRepository {
  TimeRepository(this._db);

  final TaskDatabase _db;

  /// Starts tracking [taskId]. If that task already has a running session the
  /// existing one is returned unchanged (idempotent), so a double-tap on the
  /// start button cannot create two overlapping sessions.
  ///
  /// Any *other* running session is stopped first (see the class invariant).
  Future<TimeSession> startSession(
    String taskId, {
    bool isPomodoro = false,
    String? label,
  }) async {
    final existing = await activeSession();
    if (existing != null && existing.taskId == taskId) return existing;
    if (existing != null) {
      await _close(existing);
    }

    final now = utcNow();
    final id = newId();
    final trimmed = label?.trim();
    final cleanLabel = trimmed == null || trimmed.isEmpty ? null : trimmed;
    await _db.into(_db.timeSessions).insert(
          TimeSessionsCompanion.insert(
            id: id,
            taskId: taskId,
            startedAt: now,
            isPomodoro: Value(isPomodoro),
            label: Value(cleanLabel),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return TimeSession(
      id: id,
      taskId: taskId,
      startedAt: now,
      durationSeconds: 0,
      isPomodoro: isPomodoro,
      label: cleanLabel,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Stops [sessionId], materializing its elapsed seconds. Returns the stopped
  /// session, or null when the id is unknown or already stopped.
  Future<TimeSession?> stopSession(String sessionId) async {
    final row = await (_db.select(_db.timeSessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    if (row == null || row.endedAt != null) return null;

    final now = utcNow();
    final elapsed = now.difference(row.startedAt.toUtc()).inSeconds;
    final seconds = elapsed < 0 ? 0 : elapsed;

    await (_db.update(_db.timeSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      TimeSessionsCompanion(
        endedAt: Value(now),
        durationSeconds: Value(seconds),
        updatedAt: Value(now),
      ),
    );

    return _toSession(row, endedAt: now, durationSeconds: seconds);
  }

  /// Stops whatever session is currently running, if any.
  Future<TimeSession?> stopActiveSession() async {
    final active = await activeSession();
    if (active == null) return null;
    return stopSession(active.id);
  }

  /// Soft-deletes a session (it stops contributing to totals).
  Future<void> deleteSession(String sessionId) async {
    final now = utcNow();
    await (_db.update(_db.timeSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      TimeSessionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Adds a manual time entry with explicit start/end times.
  ///
  /// Useful for logging past work (e.g. "worked on X from 2pm–4pm yesterday").
  /// The session is inserted as completed (not running).
  Future<TimeSession> addManualSession({
    required String taskId,
    required DateTime startedAt,
    required DateTime endedAt,
    bool isPomodoro = false,
    String? label,
  }) async {
    final trimmed = label?.trim();
    final cleanLabel = trimmed == null || trimmed.isEmpty ? null : trimmed;
    final duration = endedAt.toUtc().difference(startedAt.toUtc()).inSeconds;
    final now = utcNow();
    final id = newId();

    await _db.into(_db.timeSessions).insert(
      TimeSessionsCompanion.insert(
        id: id,
        taskId: taskId,
        startedAt: startedAt.toUtc(),
        endedAt: Value(endedAt.toUtc()),
        durationSeconds: Value(duration < 0 ? 0 : duration),
        isPomodoro: Value(isPomodoro),
        label: Value(cleanLabel),
        createdAt: now,
        updatedAt: now,
      ),
    );

    return TimeSession(
      id: id,
      taskId: taskId,
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      durationSeconds: duration < 0 ? 0 : duration,
      isPomodoro: isPomodoro,
      label: cleanLabel,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// The single running session, or null when nothing is being tracked.
  Future<TimeSession?> activeSession() async {
    final row = await (_db.select(_db.timeSessions)
          ..where((s) => s.endedAt.isNull() & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .getSingleOrNull();
    return row == null ? null : _toSession(row);
  }

  /// Convenience: the running session for [taskId] specifically.
  Future<TimeSession?> activeSessionFor(String taskId) async {
    final session = await activeSession();
    if (session == null || session.taskId != taskId) return null;
    return session;
  }

  /// True when [taskId] currently has a running session.
  Future<bool> isTracking(String taskId) async =>
      (await activeSessionFor(taskId)) != null;

  Future<TimeSession?> byId(String sessionId) async {
    final row = await (_db.select(_db.timeSessions)
          ..where((s) => s.id.equals(sessionId)))
        .getSingleOrNull();
    return row == null ? null : _toSession(row);
  }

  /// Every active session for [taskId], newest first.
  Future<List<TimeSession>> sessionsForTask(String taskId, {int? limit}) async {
    final query = _db.select(_db.timeSessions)
      ..where((s) => s.taskId.equals(taskId) & s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return [for (final row in rows) _toSession(row)];
  }

  /// Every active session across all tasks, newest first.
  Future<List<TimeSession>> allTimeSessions() async {
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
    return [for (final row in rows) _toSession(row)];
  }

  /// Total tracked seconds for [taskId] across all time.
  ///
  /// A running session contributes its live elapsed time as of [now] so the
  /// figure on screen ticks up while the timer runs.
  Future<int> totalSecondsForTask(
    String taskId, {
    DateTime? now,
    DateTime? since,
  }) async {
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.taskId.equals(taskId) & s.deletedAt.isNull()))
        .get();
    var total = 0;
    for (final row in rows) {
      if (since != null && row.startedAt.toUtc().isBefore(since.toUtc())) continue;
      total += row.endedAt == null
          ? _runningSeconds(row.startedAt, now)
          : row.durationSeconds;
    }
    return total;
  }

  /// Total tracked seconds for [taskId] restricted to sessions that started on
  /// or after [since].
  Future<int> totalSecondsForTaskSince(
    String taskId,
    DateTime since, {
    DateTime? now,
  }) =>
      totalSecondsForTask(taskId, now: now, since: since);

  /// Tracked seconds across *all* tasks for sessions that started at or after
  /// [since] — the total for a period rather than a per-task figure.
  ///
  /// A running session contributes its live elapsed time as of [now], matching
  /// [totalSecondsForTask] and [dailyTotals] so a running timer shows up in
  /// every total at once.
  Future<int> totalSecondsBetween(DateTime since, {DateTime? now}) async {
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.deletedAt.isNull()))
        .get();
    final floor = since.toUtc();
    var total = 0;
    for (final row in rows) {
      if (row.startedAt.toUtc().isBefore(floor)) continue;
      total += row.endedAt == null
          ? _runningSeconds(row.startedAt, now)
          : row.durationSeconds;
    }
    return total;
  }

  /// How many sessions started at or after [since]. A still-running session
  /// counts as one.
  Future<int> sessionCountSince(DateTime since, {DateTime? now}) async {
    final floor = since.toUtc();
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.deletedAt.isNull()))
        .get();
    var count = 0;
    for (final row in rows) {
      if (row.startedAt.toUtc().isBefore(floor)) continue;
      count++;
    }
    return count;
  }

  /// The [limit] most recent sessions across all tasks, newest first.
  ///
  /// Backs the Time tab's session log. Unlike [sessionsForTask] this crosses
  /// task boundaries, and it includes the running session so the log's top
  /// entry is whatever the user is doing right now.
  Future<List<TimeSession>> recentSessions({int limit = 40}) async {
    final query = _db.select(_db.timeSessions)
      ..where((s) => s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    query.limit(limit);
    final rows = await query.get();
    return [for (final row in rows) _toSession(row)];
  }

  /// Tracked seconds grouped by task id, for list rendering in one query.
  /// Running sessions contribute their live elapsed time as of [now].
  Future<Map<String, int>> totalsByTask({DateTime? now, DateTime? since}) async {
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.deletedAt.isNull()))
        .get();
    final totals = <String, int>{};
    for (final row in rows) {
      if (since != null && row.startedAt.toUtc().isBefore(since.toUtc())) continue;
      final id = row.taskId;
      totals[id] = (totals[id] ?? 0) +
          (row.endedAt == null
              ? _runningSeconds(row.startedAt, now)
              : row.durationSeconds);
    }
    return totals;
  }

  /// Total tracked seconds for the local calendar day of [day].
  Future<int> totalSecondsForDay(DateTime day, {DateTime? now}) async {
    final start = DateTime(day.year, day.month, day.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.deletedAt.isNull()))
        .get();

    var total = 0;
    for (final row in rows) {
      final started = row.startedAt.toUtc();
      if (started.isBefore(start) || !started.isBefore(end)) continue;
      total += row.endedAt == null
          ? _runningSeconds(row.startedAt, now)
          : row.durationSeconds;
    }
    return total;
  }

  /// Total tracked seconds across every task for the local calendar day of
  /// [day]. Convenience wrapper over [totalSecondsForDay].
  Future<int> totalSecondsForToday({DateTime? now, DateTime? today}) =>
      totalSecondsForDay(today ?? DateTime.now(), now: now);

  /// Number of time sessions started on the local calendar day of [day].
  /// Soft-deleted sessions are excluded; a still-running session counts as
  /// one. Paired with [totalSecondsForDay] so a summary can say
  /// "40 min across 3 sessions" rather than minutes alone.
  Future<int> sessionCountForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.deletedAt.isNull()))
        .get();
    return rows.where((row) {
      final started = row.startedAt.toUtc();
      return !started.isBefore(start) && started.isBefore(end);
    }).length;
  }

  /// Tracked seconds per local calendar day for the last [days] days, keyed by
  /// `isoDate`, oldest first. Feeds the "this week" strip on the task screen.
  /// Days with no sessions are present with a zero value.
  Future<Map<String, int>> dailyTotals({
    int days = 7,
    DateTime? today,
    DateTime? now,
  }) async {
    final anchor = calendarDate(today ?? DateTime.now());
    final start = DateTime(anchor.year, anchor.month, anchor.day - (days - 1));
    final rows = await (_db.select(_db.timeSessions)
          ..where((s) => s.deletedAt.isNull()))
        .get();

    final totals = <String, int>{};
    for (var i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      totals[_key(day)] = 0;
    }
    for (final row in rows) {
      final key = _key(row.startedAt.toLocal());
      if (!totals.containsKey(key)) continue;
      totals[key] = totals[key]! +
          (row.endedAt == null
              ? _runningSeconds(row.startedAt, now)
              : row.durationSeconds);
    }
    return totals;
  }

  /// Elapsed seconds for a session that started at [startedAt] and is still
  /// running, as of [now]. Floored at zero so a clock skew can never produce a
  /// negative total.
  static int _runningSeconds(DateTime startedAt, DateTime? now) {
    final elapsed = (now ?? utcNow()).toUtc().difference(startedAt.toUtc());
    return elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  }

  static String _key(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Future<void> _close(TimeSession session) =>
      stopSession(session.id).then((_) {});

  TimeSession _toSession(
    dynamic row, {
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return TimeSession(
      id: row.id as String,
      taskId: row.taskId as String,
      startedAt: (row.startedAt as DateTime).toUtc(),
      endedAt: endedAt ?? (row.endedAt as DateTime?)?.toUtc(),
      durationSeconds: durationSeconds ?? (row.durationSeconds as int),
      isPomodoro: (row.isPomodoro as bool),
      label: row.label as String?,
      createdAt: (row.createdAt as DateTime).toUtc(),
      updatedAt: (row.updatedAt as DateTime).toUtc(),
      deletedAt: (row.deletedAt as DateTime?)?.toUtc(),
    );
  }
}
