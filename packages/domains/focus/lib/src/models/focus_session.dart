enum FocusMode {
  pomodoro('Pomodoro (25m)', 1500),
  deepWork('Deep Work (50m)', 3000),
  shortBreak('Short Break (5m)', 300),
  longBreak('Long Break (15m)', 900),
  custom('Custom', 0);

  const FocusMode(this.label, this.defaultSeconds);
  final String label;
  final int defaultSeconds;

  static FocusMode fromString(String name) {
    return FocusMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => FocusMode.pomodoro,
    );
  }
}

class FocusSession {
  const FocusSession({
    required this.id,
    this.taskId,
    this.taskTitle,
    required this.durationSeconds,
    required this.completedAt,
    required this.mode,
    this.notes,
  });

  final String id;
  final String? taskId;
  final String? taskTitle;
  final int durationSeconds;
  final DateTime completedAt;
  final FocusMode mode;
  final String? notes;

  int get durationMinutes => (durationSeconds / 60).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'durationSeconds': durationSeconds,
        'completedAt': completedAt.toIso8601String(),
        'mode': mode.name,
        'notes': notes,
      };
}
