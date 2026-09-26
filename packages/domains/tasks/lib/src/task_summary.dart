import 'package:lifeos_core/lifeos_core.dart'
    show
        DomainSummary,
        HighlightAction,
        HighlightedItem,
        calendarDate,
        isSameDay,
        isoDate,
        todayLocal;

import 'task.dart';
import 'task_repository.dart';
import 'time_repository.dart';

/// Builds the Tasks contribution to the home overview
/// (domain-summary-contract.md).
///
/// Counts (fixed keys): `outstanding`, `overdue` (outstanding with a due
/// date strictly before today), `completedToday` (completed with
/// `updatedAt` falling on today), `trackedSeconds` / `trackedMinutes` /
/// `trackedSessions` for today's tracked time. Highlighted: up to 3
/// actionable tasks — overdue first (earliest due), then nearest-due future
/// tasks — kind `task.overdue` / `task.due`, always with a `complete` action.
/// Undated and completed tasks never appear in highlights.
class TaskSummaryBuilder {
  TaskSummaryBuilder(this._repository, [TimeRepository? timeRepository])
      : _time = timeRepository;

  final TaskRepository _repository;
  final TimeRepository? _time;

  Future<DomainSummary> build({DateTime? today}) async {
    final t = today == null ? todayLocal() : calendarDate(today);
    final tasks = await _repository.all();

    final outstanding = tasks.where((task) => !task.isCompleted).toList();
    final overdue =
        outstanding.where((task) => task.isOverdue(t)).toList()..sort(_byDue);
    final completedToday = tasks
        .where((task) => task.isCompleted && isSameDay(task.updatedAt.toLocal(), t))
        .toList();

    final upcoming = outstanding
        .where((task) => task.dueDate != null && !task.isOverdue(t))
        .toList()
      ..sort(_byDue);

    final highlighted = <HighlightedItem>[
      for (final task in [...overdue, ...upcoming].take(3))
        HighlightedItem(
          id: task.id,
          kind: overdue.contains(task) ? 'task.overdue' : 'task.due',
          title: task.title,
          subtitle: 'Due ${isoDate(task.dueDate!)}',
          action: HighlightAction.complete,
        ),
    ];

    final trackedSeconds = await _time?.totalSecondsForDay(t) ?? 0;
    final trackedSessions = await _time?.sessionCountForDay(t) ?? 0;

    return DomainSummary(
      domainKey: 'tasks',
      displayName: 'Tasks',
      counts: {
        'outstanding': outstanding.length,
        'overdue': overdue.length,
        'completedToday': completedToday.length,
        'trackedSeconds': trackedSeconds,
        'trackedMinutes': trackedSeconds ~/ 60,
        'trackedSessions': trackedSessions,
      },
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }

  /// Earliest due date first (both overdue and upcoming use this).
  static int _byDue(Task a, Task b) => a.dueDate!.compareTo(b.dueDate!);
}