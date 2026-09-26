enum AchievementTier {
  bronze('Bronze', '🥉'),
  silver('Silver', '🥈'),
  gold('Gold', '🥇'),
  diamond('Diamond', '💎');

  const AchievementTier(this.label, this.icon);
  final String label;
  final String icon;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.domain,
    required this.tier,
    required this.targetValue,
    required this.currentValue,
    required this.isUnlocked,
    this.unlockedAt,
    required this.xpReward,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final String domain;
  final AchievementTier tier;
  final int targetValue;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int xpReward;

  double get progressRatio {
    if (targetValue <= 0) return 1.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    String? domain,
    AchievementTier? tier,
    int? targetValue,
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? xpReward,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      domain: domain ?? this.domain,
      tier: tier ?? this.tier,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      xpReward: xpReward ?? this.xpReward,
    );
  }
}
