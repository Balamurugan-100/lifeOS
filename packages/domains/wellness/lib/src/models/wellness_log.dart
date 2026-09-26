class WellnessLog {
  const WellnessLog({
    required this.id,
    required this.date,
    this.sleepDurationMinutes = 420, // 7 hours default
    this.sleepQualityScore = 4, // 1 to 5
    this.energyScore = 4, // 1 to 5
    this.stepCount = 0,
    this.waterMl = 2000,
    this.factors = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String date;
  final int sleepDurationMinutes;
  final int sleepQualityScore;
  final int energyScore;
  final int stepCount;
  final int waterMl;
  final List<String> factors;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get sleepHours => sleepDurationMinutes / 60.0;

  String get formattedSleepHours {
    final hours = sleepDurationMinutes ~/ 60;
    final mins = sleepDurationMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String get energyEmoji => switch (energyScore) {
        5 => '⚡ Supercharged',
        4 => '🔋 High Energy',
        3 => '⚖️ Balanced',
        2 => '🥱 Drained',
        _ => '🪫 Depleted',
      };

  String get sleepQualityLabel => switch (sleepQualityScore) {
        5 => '🌟 Restorative (Deep)',
        4 => '✨ Great Sleep',
        3 => '💤 Fair Rest',
        2 => '🌙 Restless',
        _ => '😫 Poor Sleep',
      };

  WellnessLog copyWith({
    String? id,
    String? date,
    int? sleepDurationMinutes,
    int? sleepQualityScore,
    int? energyScore,
    int? stepCount,
    int? waterMl,
    List<String>? factors,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WellnessLog(
      id: id ?? this.id,
      date: date ?? this.date,
      sleepDurationMinutes: sleepDurationMinutes ?? this.sleepDurationMinutes,
      sleepQualityScore: sleepQualityScore ?? this.sleepQualityScore,
      energyScore: energyScore ?? this.energyScore,
      stepCount: stepCount ?? this.stepCount,
      waterMl: waterMl ?? this.waterMl,
      factors: factors ?? this.factors,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
