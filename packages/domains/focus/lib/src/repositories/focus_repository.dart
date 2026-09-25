import 'package:drift/drift.dart';

import '../database/focus_database.dart';
import '../models/focus_session.dart';

class FocusRepository {
  FocusRepository(this._db);

  final FocusDatabase _db;

  FocusSession _mapToDomain(FocusSessionData row) {
    return FocusSession(
      id: row.id,
      taskId: row.taskId,
      taskTitle: row.taskTitle,
      durationSeconds: row.durationSeconds,
      completedAt: row.completedAt,
      mode: FocusMode.fromString(row.mode),
      notes: row.notes,
    );
  }

  Future<FocusSession> recordSession({
    required String id,
    String? taskId,
    String? taskTitle,
    required int durationSeconds,
    required DateTime completedAt,
    required FocusMode mode,
    String? notes,
  }) async {
    final newRow = FocusSessionsCompanion.insert(
      id: id,
      taskId: Value(taskId),
      taskTitle: Value(taskTitle),
      durationSeconds: durationSeconds,
      completedAt: completedAt,
      mode: Value(mode.name),
      notes: Value(notes),
    );
    await _db.into(_db.focusSessions).insert(newRow);
    return FocusSession(
      id: id,
      taskId: taskId,
      taskTitle: taskTitle,
      durationSeconds: durationSeconds,
      completedAt: completedAt,
      mode: mode,
      notes: notes,
    );
  }

  Future<List<FocusSession>> getAllSessions() async {
    final rows = await (_db.select(_db.focusSessions)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.completedAt,
                  mode: OrderingMode.desc,
                )
          ]))
        .get();
    return rows.map(_mapToDomain).toList();
  }

  Future<int> getTodayFocusMinutes(DateTime today) async {
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await (_db.select(_db.focusSessions)
          ..where((t) =>
              t.completedAt.isBiggerOrEqualValue(startOfDay) &
              t.completedAt.isSmallerThanValue(endOfDay)))
        .get();

    final totalSeconds =
        rows.fold<int>(0, (sum, row) => sum + row.durationSeconds);
    return (totalSeconds / 60).round();
  }

  Future<Map<String, int>> getDailyFocusMinutes({int days = 7}) async {
    final now = DateTime.now();
    final result = <String, int>{};

    for (int i = days - 1; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dateKey =
          "${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
      final minutes = await getTodayFocusMinutes(targetDate);
      result[dateKey] = minutes;
    }

    return result;
  }

  Future<bool> deleteSession(String id) async {
    final count = await (_db.delete(_db.focusSessions)
          ..where((t) => t.id.equals(id)))
        .go();
    return count > 0;
  }
}
