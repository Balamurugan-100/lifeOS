/// Habit domain model (data-model.md: Habit entity).
///
/// A habit is a definition on a preset schedule (`daily` or `weekly` with a
/// weekdays subset of 1..7 where Dart `DateTime.weekday` is 1=Mon..7=Sun).
/// History lives in separate entry records; streaks are derived (streak.dart).
library;

/// Normalizes and validates a habit name per the data model: trimmed,
/// non-empty, at most 100 characters.
///
/// Shared by the [Habit] constructor and the repository so a single rule
/// governs every write (data-model.md validation).
String normalizeHabitName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be empty');
  }
  if (trimmed.length > 100) {
    throw ArgumentError.value(name, 'name', 'must be at most 100 characters');
  }
  return trimmed;
}

/// The preset recurrence a [Habit] follows. No freeform recurrence exists
/// (data-model.md: preset only).
enum ScheduleType { daily, weekly }

/// A habit's preset schedule.
///
/// `daily` carries no day set; `weekly` requires a non-empty subset of
/// 1..7 (Mon..Sun, [DateTime.weekday] convention). Weekdays are stored as an
/// unmodifiable, ascending-sorted set so equality is order-independent and
/// deterministic.
class HabitSchedule {
  /// Every day is scheduled.
  const HabitSchedule.daily()
      : type = ScheduleType.daily,
        daysOfWeek = null;

  /// A weekly schedule covering exactly the given weekdays.
  ///
  /// Throws [ArgumentError] when `days` is empty or contains a weekday outside
  /// 1..7. The set is stored normalized (sorted, unmodifiable).
  HabitSchedule.weekly(Set<int> days)
      : type = ScheduleType.weekly,
        daysOfWeek = _normalizedWeekdays(days);

  final ScheduleType type;

  /// The scheduled weekdays (1=Mon..7=Sun); non-null only for [ScheduleType.weekly].
  final Set<int>? daysOfWeek;

  /// True when [day] falls on a scheduled calendar date.
  bool isScheduled(DateTime day) =>
      type == ScheduleType.daily || daysOfWeek!.contains(day.weekday);

  @override
  bool operator ==(Object other) =>
      other is HabitSchedule &&
      other.type == type &&
      _sameWeekdays(other.daysOfWeek, daysOfWeek);

  @override
  int get hashCode => Object.hash(type, daysOfWeek == null ? 0 : Object.hashAll(daysOfWeek!));

  @override
  String toString() => switch (type) {
        ScheduleType.daily => 'HabitSchedule.daily()',
        ScheduleType.weekly => 'HabitSchedule.weekly(${daysOfWeek!.toList()})',
      };

  static Set<int> _normalizedWeekdays(Set<int> days) {
    if (days.isEmpty) {
      throw ArgumentError.value(
          days, 'days', 'weekly schedule must include at least one weekday');
    }
    final unsupported = days.where((d) => d < 1 || d > 7);
    if (unsupported.isNotEmpty) {
      throw ArgumentError.value(days, 'days',
          'weekdays must be in 1..7 (Mon..Sun, Dart DateTime.weekday convention)');
    }
    final sorted = days.toList()..sort();
    return Set.unmodifiable(sorted);
  }

  static bool _sameWeekdays(Set<int>? a, Set<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

/// A habit definition: preset schedule + audit timestamps (data-model.md).
///
/// State lives in entry records, never here; this type is immutable.
class Habit {
  Habit({
    required this.id,
    required String name,
    required this.schedule,
    required this.createdAt,
    required this.updatedAt,
  }) : name = normalizeHabitName(name);

  /// Stable UUID id.
  final String id;

  /// Display name, trimmed, 1..100 chars.
  final String name;

  /// Preset recurrence (daily or weekly).
  final HabitSchedule schedule;

  /// Creation instant, UTC.
  final DateTime createdAt;

  /// Last write instant, UTC.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Habit &&
      other.id == id &&
      other.name == name &&
      other.schedule == schedule &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, schedule, createdAt, updatedAt);

  @override
  String toString() => 'Habit($name: $schedule)';
}