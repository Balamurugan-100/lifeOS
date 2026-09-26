enum RitualType {
  morning,
  evening,
  custom;

  static RitualType fromString(String value) {
    return switch (value.toLowerCase()) {
      'morning' => RitualType.morning,
      'evening' => RitualType.evening,
      _ => RitualType.custom,
    };
  }
}

class RitualStep {
  const RitualStep({
    required this.id,
    required this.ritualId,
    required this.title,
    this.description,
    this.durationMinutes = 5,
    this.orderIndex = 0,
    this.isCompleted = false,
  });

  final String id;
  final String ritualId;
  final String title;
  final String? description;
  final int durationMinutes;
  final int orderIndex;
  final bool isCompleted;

  RitualStep copyWith({
    String? id,
    String? ritualId,
    String? title,
    String? description,
    int? durationMinutes,
    int? orderIndex,
    bool? isCompleted,
  }) {
    return RitualStep(
      id: id ?? this.id,
      ritualId: ritualId ?? this.ritualId,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      orderIndex: orderIndex ?? this.orderIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class Ritual {
  const Ritual({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.iconName = 'routine',
    this.colorHex = '#38BDF8',
    this.steps = const [],
    this.isActive = true,
    this.streak = 0,
    this.lastCompletedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final RitualType type;
  final String? description;
  final String iconName;
  final String colorHex;
  final List<RitualStep> steps;
  final bool isActive;
  final int streak;
  final String? lastCompletedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalMinutes =>
      steps.fold<int>(0, (sum, step) => sum + step.durationMinutes);

  int get completedStepsCount =>
      steps.where((step) => step.isCompleted).length;

  double get completionProgress =>
      steps.isEmpty ? 0.0 : (completedStepsCount / steps.length).clamp(0.0, 1.0);

  bool get isCompletedToday {
    if (lastCompletedDate == null) return false;
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return lastCompletedDate == today;
  }
}
