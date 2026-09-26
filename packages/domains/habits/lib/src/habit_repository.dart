import 'package:drift/drift.dart'
    show BooleanExpressionOperators, DoNothing, OrderingTerm, Value;
import 'package:lifeos_core/lifeos_core.dart' show calendarDate, newId;
import 'package:lifeos_storage/lifeos_storage.dart' show utcNow;

import 'habit.dart';
import 'habit_database.dart' hide Habit;

/// Repository over the Habits domain tables (data-model.md).
///
/// The schedule is serialized as `schedule_type` + an ascending comma-joined
/// weekdays string; all writes refresh `updated_at` on the habit row. Entry
/// dates are normalized to local calendar dates before storing/querying.
class HabitRepository {
  HabitRepository(this._db);

  final HabitDatabase _db;

  /// All habits in registration order (`created_at` asc, tie-broken by id).
  Future<List<Habit>> all() async {
    final rows = await (_db.select(_db.habits)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return [for (final row in rows) _toHabit(row)];
  }

  Future<Habit?> byId(String id) async {
    final row = await (_db.select(_db.habits)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _toHabit(row);
  }

  /// Creates a habit with fresh UUID + UTC audit timestamps.
  Future<Habit> define(
    String name, {
    HabitSchedule schedule = const HabitSchedule.daily(),
  }) async {
    final normalized = normalizeHabitName(name);
    final now = utcNow();
    final id = newId();
    await _db.into(_db.habits).insert(
          HabitsCompanion.insert(
            id: id,
            name: normalized,
            scheduleType: schedule.type.name,
            daysOfWeek: Value(_daysOfWeekCsv(schedule)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return Habit(
      id: id,
      name: normalized,
      schedule: schedule,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Renames (and re-trims) the habit, refreshing `updated_at`.
  Future<void> rename(String id, String name) async {
    final normalized = normalizeHabitName(name);
    await (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
          HabitsCompanion(
            name: Value(normalized),
            updatedAt: Value(utcNow()),
          ),
        );
  }

  /// Soft-deletes the habit (tombstone for future sync).
  Future<void> delete(String id) async {
    await (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
          HabitsCompanion(
            deletedAt: Value(utcNow()),
            updatedAt: Value(utcNow()),
          ),
        );
  }

  /// True when [date] has a recorded entry for the habit.
  Future<bool> isDone(String habitId, DateTime date) async {
    final t = calendarDate(date);
    final row = await (_db.select(_db.habitEntries)
          ..where((e) => e.habitId.equals(habitId) & e.date.equals(t)))
        .getSingleOrNull();
    return row != null;
  }

  /// Idempotently records a completion for [date] (unique (habitId, date)):
  /// recording twice is a no-op. The stored date is the calendar date.
  Future<void> record(String habitId, DateTime date) async {
    final t = calendarDate(date);
    final now = utcNow();
    await _db.into(_db.habitEntries).insert(
          HabitEntriesCompanion.insert(
            id: newId(),
            habitId: habitId,
            date: t,
            completedAt: now,
            createdAt: now,
          ),
          onConflict: DoNothing(
            target: [_db.habitEntries.habitId, _db.habitEntries.date],
          ),
        );
  }

  /// Removes the entry for [date] (idempotent; missing row is a no-op).
  Future<void> unrecord(String habitId, DateTime date) async {
    final t = calendarDate(date);
    await (_db.delete(_db.habitEntries)
          ..where((e) => e.habitId.equals(habitId) & e.date.equals(t)))
        .go();
  }

  /// All recorded entry dates for the habit, ascending [DateTime]s with the
  /// time component stripped.
  Future<List<DateTime>> entryDates(String habitId) async {
    final rows = await (_db.select(_db.habitEntries)
          ..where((t) => t.habitId.equals(habitId))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    return [for (final row in rows) calendarDate(row.date)];
  }

  /// Every recorded entry across all habits, deterministic order
  /// (habit, then date, then creation time). Used for the full export
  /// envelope (export-format-contract.md: completeness).
  Future<List<HabitEntry>> allEntries() async {
    final rows = await (_db.select(_db.habitEntries)
          ..orderBy([
            (t) => OrderingTerm.asc(t.habitId),
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return rows;
  }

  Habit _toHabit(dynamic row) => Habit(
        id: row.id as String,
        name: row.name as String,
        schedule: _scheduleFrom(
          row.scheduleType as String,
          row.daysOfWeek as String?,
        ),
        createdAt: (row.createdAt as DateTime).toUtc(),
        updatedAt: (row.updatedAt as DateTime).toUtc(),
        deletedAt: row.deletedAt != null ? (row.deletedAt as DateTime).toUtc() : null,
      );

  /// 'daily' | 'weekly' + weekdays csv -> domain [HabitSchedule].
  static HabitSchedule _scheduleFrom(String type, String? daysCsv) {
    if (type == 'weekly') {
      final weekdays = daysCsv!.split(',').map(int.parse).toList()..sort();
      return HabitSchedule.weekly(weekdays.toSet());
    }
    return const HabitSchedule.daily();
  }

  /// Domain [HabitSchedule] -> comma-joined sorted weekdays, null for daily.
  static String? _daysOfWeekCsv(HabitSchedule schedule) {
    final days = schedule.daysOfWeek;
    if (days == null) return null;
    final sorted = days.toList()..sort();
    return sorted.join(',');
  }
}