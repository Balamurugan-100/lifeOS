enum GoalCategory {
  career('Career & Work', '💼'),
  health('Health & Fitness', '🏃'),
  finance('Financial Freedom', '💰'),
  learning('Skills & Learning', '📚'),
  personal('Personal & Life', '🌟');

  const GoalCategory(this.label, this.icon);
  final String label;
  final String icon;

  static GoalCategory fromString(String name) {
    return GoalCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => GoalCategory.personal,
    );
  }
}

enum GoalStatus {
  inProgress('In Progress'),
  completed('Completed'),
  paused('Paused');

  const GoalStatus(this.label);
  final String label;

  static GoalStatus fromString(String name) {
    return GoalStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => GoalStatus.inProgress,
    );
  }
}

class GoalMilestone {
  const GoalMilestone({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final bool isCompleted;

  GoalMilestone copyWith({String? id, String? title, bool? isCompleted}) {
    return GoalMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory GoalMilestone.fromJson(Map<String, dynamic> json) {
    return GoalMilestone(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.status = GoalStatus.inProgress,
    required this.targetValue,
    this.currentValue = 0.0,
    this.unit = '%',
    this.targetDate,
    this.linkedHabitId,
    this.linkedTaskId,
    this.milestones = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final GoalCategory category;
  final GoalStatus status;
  final double targetValue;
  final double currentValue;
  final String unit;
  final DateTime? targetDate;
  final String? linkedHabitId;
  final String? linkedTaskId;
  final List<GoalMilestone> milestones;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get progressRatio {
    if (milestones.isNotEmpty) {
      final done = milestones.where((m) => m.isCompleted).length;
      return done / milestones.length;
    }
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressRatio * 100).round();

  bool get isCompleted => status == GoalStatus.completed || progressRatio >= 1.0;

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    GoalCategory? category,
    GoalStatus? status,
    double? targetValue,
    double? currentValue,
    String? unit,
    DateTime? targetDate,
    String? linkedHabitId,
    String? linkedTaskId,
    List<GoalMilestone>? milestones,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      targetDate: targetDate ?? this.targetDate,
      linkedHabitId: linkedHabitId ?? this.linkedHabitId,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      milestones: milestones ?? this.milestones,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'status': status.name,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'unit': unit,
        'targetDate': targetDate?.toIso8601String(),
        'linkedHabitId': linkedHabitId,
        'linkedTaskId': linkedTaskId,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
