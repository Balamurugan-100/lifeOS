class LifeBalance {
  const LifeBalance({
    required this.productivity,
    required this.discipline,
    required this.wealth,
    required this.mind,
    required this.growth,
  });

  final double productivity; // Tasks & Focus (0..100)
  final double discipline;   // Habits & Streaks (0..100)
  final double wealth;       // Finance & Budget (0..100)
  final double mind;         // Journal & Mood (0..100)
  final double growth;       // Goals & Notes/Docs (0..100)

  int get overallScore {
    final avg = (productivity + discipline + wealth + mind + growth) / 5.0;
    return avg.round().clamp(0, 100);
  }

  String get harmonyRating {
    final score = overallScore;
    if (score >= 85) return '✨ Peak Harmony';
    if (score >= 70) return '⚡ High Equilibrium';
    if (score >= 50) return '🌱 Steady Balance';
    return '🔄 Calibrating';
  }

  static const LifeBalance empty = LifeBalance(
    productivity: 0,
    discipline: 0,
    wealth: 0,
    mind: 0,
    growth: 0,
  );
}
