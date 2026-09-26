enum BlockCategory {
  focus,
  routine,
  meeting,
  breakTime,
  personal,
  health;

  static BlockCategory fromString(String value) {
    return switch (value.toLowerCase()) {
      'focus' => BlockCategory.focus,
      'routine' => BlockCategory.routine,
      'meeting' => BlockCategory.meeting,
      'breaktime' || 'break' => BlockCategory.breakTime,
      'personal' => BlockCategory.personal,
      'health' => BlockCategory.health,
      _ => BlockCategory.focus,
    };
  }
}

class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.title,
    required this.date,
    required this.startMinute,
    required this.durationMinutes,
    required this.category,
    this.linkedTaskId,
    this.colorHex = '#38BDF8',
    this.isCompleted = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String date;
  final int startMinute; // 0 to 1439 (minutes from midnight)
  final int durationMinutes;
  final BlockCategory category;
  final String? linkedTaskId;
  final String colorHex;
  final bool isCompleted;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get endMinute => startMinute + durationMinutes;

  String get formattedStartTime {
    final hour = startMinute ~/ 60;
    final min = startMinute % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:${min.toString().padLeft(2, '0')} $period';
  }

  String get formattedEndTime {
    final hour = endMinute ~/ 60;
    final min = endMinute % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:${min.toString().padLeft(2, '0')} $period';
  }

  String get formattedTimeRange => '$formattedStartTime - $formattedEndTime';

  TimeBlock copyWith({
    String? id,
    String? title,
    String? date,
    int? startMinute,
    int? durationMinutes,
    BlockCategory? category,
    String? linkedTaskId,
    String? colorHex,
    bool? isCompleted,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      startMinute: startMinute ?? this.startMinute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      colorHex: colorHex ?? this.colorHex,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
