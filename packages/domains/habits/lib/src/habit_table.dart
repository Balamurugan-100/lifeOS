import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;

/// Drift table backing the `Habit` domain entity (data-model.md).
///
/// Schedule is stored denormalized as `schedule_type` ('daily' | 'weekly')
/// plus a comma-joined, ascending-sorted weekdays string for weekly schedules
/// (null for daily).
class Habits extends Table with AuditFields {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// 'daily' | 'weekly'
  TextColumn get scheduleType => text()();

  /// Comma-joined sorted weekdays for weekly, null for daily.
  TextColumn get daysOfWeek => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}