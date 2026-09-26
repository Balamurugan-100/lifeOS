import 'dart:math' as math;

class LifeXpProfile {
  const LifeXpProfile({
    required this.totalXp,
    required this.streakBonusXp,
    required this.todayXp,
    required this.lastUpdated,
  });

  final int totalXp;
  final int streakBonusXp;
  final int todayXp;
  final DateTime lastUpdated;

  int get level {
    if (totalXp <= 0) return 1;
    return (math.sqrt(totalXp / 50.0) + 1).floor();
  }

  int get currentLevelBaseXp {
    final lvl = level;
    if (lvl <= 1) return 0;
    return ((lvl - 1) * (lvl - 1) * 50);
  }

  int get nextLevelTargetXp {
    final lvl = level;
    return (lvl * lvl * 50);
  }

  int get xpIntoCurrentLevel => totalXp - currentLevelBaseXp;
  int get xpRequiredForCurrentLevel => nextLevelTargetXp - currentLevelBaseXp;

  double get progressToNextLevel {
    if (xpRequiredForCurrentLevel <= 0) return 0.0;
    return (xpIntoCurrentLevel / xpRequiredForCurrentLevel).clamp(0.0, 1.0);
  }

  String get rankTitle {
    final lvl = level;
    if (lvl < 3) return 'Novice Explorer';
    if (lvl < 5) return 'Routine Builder';
    if (lvl < 8) return 'Focused Strategist';
    if (lvl < 12) return 'Momentum Master';
    if (lvl < 16) return 'Productivity Vanguard';
    if (lvl < 20) return 'Grandmaster of Life';
    return 'Sovereign Achiever';
  }

  String get rankBadgeIcon {
    final lvl = level;
    if (lvl < 3) return '🌱';
    if (lvl < 5) return '⚡';
    if (lvl < 8) return '🎯';
    if (lvl < 12) return '🔥';
    if (lvl < 16) return '⚔️';
    if (lvl < 20) return '👑';
    return '🌟';
  }

  LifeXpProfile copyWith({
    int? totalXp,
    int? streakBonusXp,
    int? todayXp,
    DateTime? lastUpdated,
  }) {
    return LifeXpProfile(
      totalXp: totalXp ?? this.totalXp,
      streakBonusXp: streakBonusXp ?? this.streakBonusXp,
      todayXp: todayXp ?? this.todayXp,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class XpTransaction {
  const XpTransaction({
    required this.id,
    required this.amount,
    required this.domain,
    required this.reason,
    required this.timestamp,
  });

  final String id;
  final int amount;
  final String domain;
  final String reason;
  final DateTime timestamp;
}
