import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../app.dart';
import '../home/home_controller.dart';

/// Live task list for the Tasks screen (T041).
final taskListProvider = FutureProvider<List<Task>>((ref) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.all();
});

/// Total tracked seconds per task id — the "how much time did I spend on this"
/// figure shown on every tile. Invalidated whenever a session starts or stops
/// (see [invalidateTime]), never polled.
final taskTimeTotalsProvider = FutureProvider<Map<String, int>>((ref) async {
  final time = await ref.watch(timeRepositoryProvider.future);
  return time.totalsByTask();
});

/// The one in-flight session, if any. There can be at most one by design: a
/// start on a new task stops the previous one. Invalidated on mutation; the
/// smooth per-second advance comes from a `TickingTimer` instead of polling.
final activeTimeSessionProvider = FutureProvider<TimeSession?>((ref) async {
  final time = await ref.watch(timeRepositoryProvider.future);
  return time.activeSession();
});

/// Tracked seconds today, used by the summary bar above the task list.
final trackedTodayProvider = FutureProvider<({int seconds, int sessions})>(
  (ref) async {
    final time = await ref.watch(timeRepositoryProvider.future);
    return (
      seconds: await time.totalSecondsForToday(),
      sessions: await time.sessionCountForDay(todayLocal()),
    );
  },
);

/// Recent sessions newest first, for the Time tab's log.
final timeSessionsLogProvider = FutureProvider<List<TimeSession>>((ref) async {
  final time = await ref.watch(timeRepositoryProvider.future);
  return time.recentSessions(limit: 40);
});

/// Refreshes everything derived from the TimeSessions table.
///
/// Called after every start/stop/delete so the task tiles, the summary bar,
/// the Time tab and the home summary all stay consistent. There is no polling
/// anywhere — a running session's per-second advance is a local `TickingTimer`
/// over a `Stopwatch`, which is both cheaper and immune to missed ticks while
/// the app is backgrounded.
void invalidateTime(WidgetRef ref) {
  ref.invalidate(taskTimeTotalsProvider);
  ref.invalidate(activeTimeSessionProvider);
  ref.invalidate(trackedTodayProvider);
  ref.invalidate(timeSessionsLogProvider);
  ref.invalidate(timeBreakdownProvider);
  ref.invalidate(timeWeekStripProvider);
  ref.invalidate(summariesProvider);
}

/// One task's contribution to a period, already joined against the task list.
class TaskTimeShare {
  const TaskTimeShare({
    required this.taskId,
    required this.title,
    required this.seconds,
    this.isDeleted = false,
  });

  final String taskId;
  final String title;
  final int seconds;
  final bool isDeleted;
}

/// Totals for the currently selected range.
class TimePeriodTotals {
  const TimePeriodTotals({required this.seconds, required this.sessions});

  final int seconds;
  final int sessions;
}

/// Tracked seconds for one day, for the seven-day strip.
class TimeDayTotal {
  const TimeDayTotal({required this.label, required this.seconds});

  final String label;
  final int seconds;
}

/// Midnight UTC of the day [days] days back, matching the day boundary
/// `TimeRepository` uses for its own aggregates.
DateTime _sinceFor(int days) {
  final now = todayLocal();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: days - 1))
      .toUtc();
}

/// Inclusive day offset the whole Time tab is scoped to: `0` means today,
/// `7` means the last seven days. An int rather than an enum because it also
/// keys the family providers.
int timeWindowDays = 0;

/// Per-task tracked seconds for the window, biggest first.
final timeBreakdownProvider =
    FutureProvider.family<List<TaskTimeShare>, int>((ref, days) async {
  final time = await ref.watch(timeRepositoryProvider.future);
  final totals = await time.totalsByTask(
    since: days == 0 ? null : _sinceFor(days),
  );
  if (totals.isEmpty) return const [];

  final tasks = await ref.watch(taskListProvider.future);
  final titles = {for (final t in tasks) t.id: t.title};
  final deleted = {for (final t in tasks) t.id: t.deletedAt != null};

  final shares = <TaskTimeShare>[];
  for (final entry in totals.entries) {
    if (entry.value <= 0) continue;
    shares.add(TaskTimeShare(
      taskId: entry.key,
      title: titles[entry.key] ?? 'Deleted task',
      seconds: entry.value,
      isDeleted: titles.containsKey(entry.key) && deleted[entry.key] == true,
    ));
  }
  shares.sort((a, b) => b.seconds.compareTo(a.seconds));
  return shares;
});

/// Tracked seconds per day for the last 7 days, oldest first.
final timeWeekStripProvider = FutureProvider<List<TimeDayTotal>>((ref) async {
  final time = await ref.watch(timeRepositoryProvider.future);
  final totals = await time.dailyTotals(days: 7);
  final today = todayLocal();
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    return TimeDayTotal(
      label: labels[day.weekday - 1],
      seconds: totals[isoDate(day)] ?? 0,
    );
  });
});

/// Total seconds plus session count for the window.
final timePeriodTotalsProvider =
    FutureProvider.family<TimePeriodTotals, int>((ref, days) async {
  final time = await ref.watch(timeRepositoryProvider.future);
  if (days == 0) {
    return TimePeriodTotals(
      seconds: await time.totalSecondsForDay(todayLocal()),
      sessions: await time.sessionCountForDay(todayLocal()),
    );
  }
  final since = _sinceFor(days);
  return TimePeriodTotals(
    seconds: await time.totalSecondsBetween(since, now: todayLocal()),
    sessions: await time.sessionCountSince(since, now: todayLocal()),
  );
});