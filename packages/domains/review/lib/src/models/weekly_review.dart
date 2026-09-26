class WeeklyReview {
  const WeeklyReview({
    required this.id,
    required this.weekStartDate, // e.g. 2026-09-21
    this.rating = 4, // 1 to 5
    this.biggestWin = '',
    this.challengeOrLesson = '',
    this.bigBets = const [],
    this.totalTasksCompleted = 0,
    this.totalHabitCheckins = 0,
    this.totalFocusMinutes = 0,
    this.netSavings = 0.0,
    this.averageMood = 4.0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String weekStartDate;
  final int rating;
  final String biggestWin;
  final String challengeOrLesson;
  final List<String> bigBets;
  final int totalTasksCompleted;
  final int totalHabitCheckins;
  final int totalFocusMinutes;
  final double netSavings;
  final double averageMood;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get formattedWeekRange {
    try {
      final start = DateTime.parse(weekStartDate);
      final end = start.add(const Duration(days: 6));
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}';
    } catch (_) {
      return weekStartDate;
    }
  }

  WeeklyReview copyWith({
    String? id,
    String? weekStartDate,
    int? rating,
    String? biggestWin,
    String? challengeOrLesson,
    List<String>? bigBets,
    int? totalTasksCompleted,
    int? totalHabitCheckins,
    int? totalFocusMinutes,
    double? netSavings,
    double? averageMood,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeeklyReview(
      id: id ?? this.id,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      rating: rating ?? this.rating,
      biggestWin: biggestWin ?? this.biggestWin,
      challengeOrLesson: challengeOrLesson ?? this.challengeOrLesson,
      bigBets: bigBets ?? this.bigBets,
      totalTasksCompleted: totalTasksCompleted ?? this.totalTasksCompleted,
      totalHabitCheckins: totalHabitCheckins ?? this.totalHabitCheckins,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      netSavings: netSavings ?? this.netSavings,
      averageMood: averageMood ?? this.averageMood,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
