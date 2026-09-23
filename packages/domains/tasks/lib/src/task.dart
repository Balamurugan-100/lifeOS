/// Task domain model (data-model.md: Task entity).
///
/// A task is a title on an optional local calendar due date with an explicit
/// completion status and a manual position for list ordering. Overdue is
/// *derived* (outstanding ∧ due before today), never stored.
library;

import 'package:lifeos_core/lifeos_core.dart' show calendarDate, isBeforeToday;

/// Normalizes and validates a task title per the data model: trimmed,
/// non-empty, at most 200 characters.
///
/// Shared by the [Task] constructor and the repository so a single rule
/// governs every write (data-model.md validation).
String normalizeTaskTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(title, 'title', 'must not be empty');
  }
  if (trimmed.length > 200) {
    throw ArgumentError.value(title, 'title', 'must be at most 200 characters');
  }
  return trimmed;
}

/// A task's lifecycle status. Completed is the only absorbing state; reopen
/// is allowed at any time (toggling is reversible).
enum TaskStatus { outstanding, completed }

/// An immutable task (data-model.md: Task entity).
class Task {
  Task({
    required this.id,
    required String title,
    required this.status,
    required this.dueDate,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  }) : title = normalizeTaskTitle(title) {
    if (position < 0) {
      throw ArgumentError.value(
          position, 'position', 'must not be negative');
    }
  }

  /// Stable UUID id.
  final String id;

  /// Display title, trimmed, 1..200 chars.
  final String title;

  /// Outstanding or completed.
  final TaskStatus status;

  /// Optional local calendar due date; null when undated. Time-of-day is
  /// deliberately not part of a due date (data-model.md conventions).
  final DateTime? dueDate;

  /// Manual ordering index; the list is sorted by position then `createdAt`
  /// (ties keep insertion order).
  final int position;

  /// Creation instant, UTC.
  final DateTime createdAt;

  /// Last write instant, UTC.
  final DateTime updatedAt;

  /// True when the task is completed (status-derived).
  bool get isCompleted => status == TaskStatus.completed;

  /// Overdue derivation: outstanding with a due date strictly before [today].
  ///
  /// Due *today* is not overdue, completed tasks are never overdue, and an
  /// undated task is never overdue (data-model.md: overdue is derived).
  bool isOverdue(DateTime today) {
    if (isCompleted) return false;
    final due = dueDate;
    if (due == null) return false;
    return isBeforeToday(calendarDate(due), calendarDate(today));
  }

  /// A copy with [dueDate] normalized to its calendar date and every field
  /// carried over — used when a lookup rounds a stored raw value.
  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.title == title &&
      other.status == status &&
      other.dueDate == dueDate &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
      id, title, status, dueDate, position, createdAt, updatedAt);

  @override
  String toString() => 'Task($title, $status, pos $position)';
}