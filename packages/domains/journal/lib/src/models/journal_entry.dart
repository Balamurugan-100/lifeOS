enum MoodType {
  awful(1, '😫', 'Awful'),
  down(2, '😔', 'Down'),
  neutral(3, '😐', 'Neutral'),
  good(4, '😊', 'Good'),
  amazing(5, '🔥', 'Amazing');

  const MoodType(this.score, this.emoji, this.label);
  final int score;
  final String emoji;
  final String label;

  static MoodType fromScore(int score) {
    return switch (score) {
      1 => MoodType.awful,
      2 => MoodType.down,
      4 => MoodType.good,
      5 => MoodType.amazing,
      _ => MoodType.neutral,
    };
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.moodScore,
    this.gratitude,
    required this.reflection,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String date; // yyyy-MM-dd
  final int moodScore; // 1..5
  final String? gratitude;
  final String reflection;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  MoodType get mood => MoodType.fromScore(moodScore);

  JournalEntry copyWith({
    String? id,
    String? date,
    int? moodScore,
    String? gratitude,
    String? reflection,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      moodScore: moodScore ?? this.moodScore,
      gratitude: gratitude ?? this.gratitude,
      reflection: reflection ?? this.reflection,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'moodScore': moodScore,
        'gratitude': gratitude,
        'reflection': reflection,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
