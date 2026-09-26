import 'package:lifeos_core/lifeos_core.dart' show isBeforeToday;

/// An immutable tracked work session against a task.
///
/// A session is *running* while [endedAt] is null. While running,
/// [durationSeconds] is not meaningful — use [elapsedAt] to render a live
/// reading, and let the repository materialize [durationSeconds] at stop time.
class TimeSession {
  TimeSession({
    required this.id,
    required this.taskId,
    required this.startedAt,
    required this.createdAt,
    required this.updatedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.isPomodoro = false,
    this.label,
    this.deletedAt,
  });

  /// Stable UUID id.
  final String id;

  /// Owning task id.
  final String taskId;

  /// Start instant, UTC.
  final DateTime startedAt;

  /// End instant, UTC; null while running.
  final DateTime? endedAt;

  /// Materialized elapsed seconds (0 while running).
  final int durationSeconds;

  /// True when started as a Pomodoro round.
  final bool isPomodoro;

  /// Optional label.
  final String? label;

  /// Creation instant, UTC.
  final DateTime createdAt;

  /// Last write instant, UTC.
  final DateTime updatedAt;

  /// Deletion instant, UTC (null if active).
  final DateTime? deletedAt;

  /// True while the session has not been stopped.
  bool get isRunning => endedAt == null;

  /// Live elapsed time. For a stopped session this is the materialized
  /// [durationSeconds]; for a running session it is `now - startedAt`, floored
  /// at zero so a clock skew can never produce a negative reading.
  Duration elapsedAt(DateTime now) {
    if (!isRunning) return Duration(seconds: durationSeconds);
    final delta = now.toUtc().difference(startedAt);
    return delta.isNegative ? Duration.zero : delta;
  }

  /// True when the session started strictly before the local calendar day of
  /// [today] (i.e. it is not part of today's total).
  bool startedBeforeDay(DateTime today) => isBeforeToday(
        startedAt.toLocal(),
        DateTime(today.year, today.month, today.day),
      );

  TimeSession copyWith({
    String? id,
    String? taskId,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    int? durationSeconds,
    bool? isPomodoro,
    String? label,
    bool clearLabel = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TimeSession(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isPomodoro: isPomodoro ?? this.isPomodoro,
      label: clearLabel ? null : (label ?? this.label),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TimeSession &&
      other.id == id &&
      other.taskId == taskId &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.durationSeconds == durationSeconds &&
      other.isPomodoro == isPomodoro &&
      other.label == label &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
        id,
        taskId,
        startedAt,
        endedAt,
        durationSeconds,
        isPomodoro,
        label,
        deletedAt,
      );

  @override
  String toString() => 'TimeSession($taskId, '
      '${isRunning ? 'running' : '${durationSeconds}s'}, pomodoro: $isPomodoro)';
}
