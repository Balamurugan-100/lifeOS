/// A user-managed task category (e.g. "Work", "Errands", "Health").
///
/// Tasks reference a category by [name], not by [id] — see
/// `task_category_table.dart` for why. The id exists so the registry row
/// survives a rename and so the UI can key on something stable.
class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    this.colorHex = defaultTaskCategoryColor,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  /// Applied to new categories when the caller does not pick a colour. A
  /// muted teal so an uncategorised-looking list still reads as calm.
  static const String defaultTaskCategoryColor = '#5FA8A0';

  final String id;
  final String name;
  final String colorHex;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  TaskCategory copyWith({
    String? name,
    String? colorHex,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TaskCategory(
      id: id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskCategory &&
      other.id == id &&
      other.name == name &&
      other.colorHex == colorHex &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, colorHex, createdAt, updatedAt, deletedAt);

  @override
  String toString() => 'TaskCategory(id: $id, name: $name, color: $colorHex)';
}

/// Thrown when a category cannot be deleted because tasks still reference it.
///
/// Callers should surface [taskCount] to the user — deleting anyway would
/// leave those tasks pointing at a name that no longer resolves in the
/// registry.
class TaskCategoryInUseException implements Exception {
  const TaskCategoryInUseException(this.categoryName, this.taskCount);

  final String categoryName;
  final int taskCount;

  @override
  String toString() =>
      'TaskCategoryInUseException: "$categoryName" is used by $taskCount '
      'task(s); reassign or clear them first.';
}

/// Thrown by [TaskCategoryRepository.add]/`update` when a name is taken.
class TaskCategoryNameTakenException implements Exception {
  const TaskCategoryNameTakenException(this.name);

  final String name;

  @override
  String toString() =>
      'TaskCategoryNameTakenException: a category named "$name" already exists.';
}
