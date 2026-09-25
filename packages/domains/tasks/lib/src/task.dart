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

/// Task priority levels: urgent (P1), high (P2), medium (P3), low (P4).
enum TaskPriority {
  urgent,
  high,
  medium,
  low;

  String get label => switch (this) {
        TaskPriority.urgent => 'Urgent',
        TaskPriority.high => 'High',
        TaskPriority.medium => 'Medium',
        TaskPriority.low => 'Low',
      };

  String get badge => switch (this) {
        TaskPriority.urgent => 'P1',
        TaskPriority.high => 'P2',
        TaskPriority.medium => 'P3',
        TaskPriority.low => 'P4',
      };
}

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
    this.priority = TaskPriority.medium,
    this.notes,
    this.category,
  }) : title = normalizeTaskTitle(title) {
    if (position < 0) {
      throw ArgumentError.value(position, 'position', 'must not be negative');
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

  /// Task priority level.
  final TaskPriority priority;

  /// Optional multi-line notes or sub-details.
  final String? notes;

  /// Optional category/tag (e.g., Work, Personal, Health, Finance).
  final String? category;

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

  Task copyWith({
    String? id,
    String? title,
    TaskStatus? status,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? position,
    TaskPriority? priority,
    String? notes,
    bool clearNotes = false,
    String? category,
    bool clearCategory = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      position: position ?? this.position,
      priority: priority ?? this.priority,
      notes: clearNotes ? null : (notes ?? this.notes),
      category: clearCategory ? null : (category ?? this.category),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.title == title &&
      other.status == status &&
      other.dueDate == dueDate &&
      other.position == position &&
      other.priority == priority &&
      other.notes == notes &&
      other.category == category &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        status,
        dueDate,
        position,
        priority,
        notes,
        category,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'Task($title, $status, priority: $priority, pos: $position)';
}