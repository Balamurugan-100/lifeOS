import 'package:drift/drift.dart';

import 'habit_table.dart';

/// Drift table backing the `HabitEntry` entity (data-model.md): a recorded
/// completion of a habit on a local calendar date.
///
/// One entry per (habitId, date) is enforced by a composite unique constraint.
/// The data model defines no `updatedAt` on entries — only createdAt.
class HabitEntries extends Table {
  TextColumn get id => text()();

  TextColumn get habitId => text().references(Habits, #id)();

  /// Local calendar date the entry belongs to.
  DateTimeColumn get date => dateTime()();

  /// When the completion was recorded, UTC.
  DateTimeColumn get completedAt => dateTime()();

  /// Creation instant, UTC.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, date},
      ];
}