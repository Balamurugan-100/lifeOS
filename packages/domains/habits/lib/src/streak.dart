import 'package:lifeos_core/lifeos_core.dart' show calendarDate;

import 'habit.dart';

/// Derives the current habit streak from present entries (data-model.md
/// derivation rules).
///
/// - `daily`: consecutive present calendar days ending at `today`, or at
///   `yesterday` when today has no entry yet (grace — the day isn't over).
/// - `weekly`: a week is Monday..Sunday (Dart `DateTime.weekday` convention),
///   and a week is *present* when at least one scheduled weekday in it has an
///   entry. Consecutive present weeks are counted ending at the current week,
///   or at the previous week when the current week has no entry (same grace).
///   Days that are not scheduled never count as missed and never make a week
///   present.
///
/// All dates are normalized to local calendar dates with [calendarDate];
/// every `subtract(Duration(...))` step is re-normalized so DST shifts cannot
/// corrupt weekday boundaries.
int currentStreak({
  required Set<DateTime> entryDates,
  required HabitSchedule schedule,
  required DateTime today,
}) {
  final entries = {for (final d in entryDates) calendarDate(d)};
  final t = calendarDate(today);

  switch (schedule.type) {
    case ScheduleType.daily:
      var cursor = entries.contains(t) ? t : _previousDay(t);
      var streak = 0;
      while (entries.contains(cursor)) {
        streak++;
        cursor = _previousDay(cursor);
      }
      return streak;

    case ScheduleType.weekly:
      var weekStart = _mondayOf(t);
      if (!_weekHasEntry(weekStart, schedule, entries)) {
        weekStart = _previousMonday(weekStart);
      }
      var streak = 0;
      while (_weekHasEntry(weekStart, schedule, entries)) {
        streak++;
        weekStart = _previousMonday(weekStart);
      }
      return streak;
  }
}

DateTime _previousDay(DateTime d) =>
    calendarDate(d.subtract(const Duration(days: 1)));

/// Monday of the Monday..Sunday week containing [d].
DateTime _mondayOf(DateTime d) =>
    calendarDate(d.subtract(Duration(days: d.weekday - 1)));

DateTime _previousMonday(DateTime monday) =>
    calendarDate(monday.subtract(const Duration(days: 7)));

/// True when any scheduled weekday of the week starting at [monday] has an
/// entry. Unscheduled weekdays are ignored entirely.
bool _weekHasEntry(
    DateTime monday, HabitSchedule schedule, Set<DateTime> entries) {
  for (final weekday in schedule.daysOfWeek!) {
    final day = calendarDate(monday.add(Duration(days: weekday - 1)));
    if (entries.contains(day)) return true;
  }
  return false;
}