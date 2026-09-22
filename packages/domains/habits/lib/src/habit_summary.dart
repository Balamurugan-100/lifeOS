import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightAction, HighlightedItem, calendarDate, todayLocal;

import 'habit.dart';
import 'habit_repository.dart';
import 'streak.dart';

/// Builds the Habits contribution to the home overview
/// (domain-summary-contract.md).
///
/// Counts (fixed keys): `doneToday` (habits with an entry on today) and
/// `streaksActive` (habits whose current streak is at least 2). Highlighted:
/// up to 3 habits that are scheduled today but not yet done, kind
/// `habit.today`, ordered by current streak desc then name. Empty when there
/// is nothing actionable.
class HabitSummaryBuilder {
  HabitSummaryBuilder(this._repository);

  final HabitRepository _repository;

  Future<DomainSummary> build({DateTime? today}) async {
    final t = today == null ? todayLocal() : calendarDate(today);
    final habits = await _repository.all();

    var doneToday = 0;
    var streaksActive = 0;
    final pending = <({Habit habit, int streak})>[];

    for (final habit in habits) {
      final dates = await _repository.entryDates(habit.id);
      final done = dates.contains(t);
      if (done) doneToday++;

      final streak = currentStreak(
        entryDates: dates.toSet(),
        schedule: habit.schedule,
        today: t,
      );
      if (streak >= 2) streaksActive++;

      if (habit.schedule.isScheduled(t) && !done) {
        pending.add((habit: habit, streak: streak));
      }
    }

    pending.sort((a, b) {
      final byStreak = b.streak.compareTo(a.streak);
      if (byStreak != 0) return byStreak;
      return a.habit.name.compareTo(b.habit.name);
    });

    final highlighted = [
      for (final item in pending.take(3))
        HighlightedItem(
          id: item.habit.id,
          kind: 'habit.today',
          title: item.habit.name,
          subtitle: 'Streak: ${item.streak}',
          action: HighlightAction.complete,
        ),
    ];

    return DomainSummary(
      domainKey: 'habits',
      displayName: 'Habits',
      counts: {'doneToday': doneToday, 'streaksActive': streaksActive},
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}