class DailyQuest {
  const DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.domain,
    required this.targetCount,
    required this.currentCount,
    required this.xpReward,
    required this.isCompleted,
    required this.isClaimed,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final String domain;
  final int targetCount;
  final int currentCount;
  final int xpReward;
  final bool isCompleted;
  final bool isClaimed;

  double get progressRatio {
    if (targetCount <= 0) return 1.0;
    return (currentCount / targetCount).clamp(0.0, 1.0);
  }

  DailyQuest copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    String? domain,
    int? targetCount,
    int? currentCount,
    int? xpReward,
    bool? isCompleted,
    bool? isClaimed,
  }) {
    return DailyQuest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      domain: domain ?? this.domain,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      xpReward: xpReward ?? this.xpReward,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }
}
