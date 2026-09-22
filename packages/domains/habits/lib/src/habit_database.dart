import 'package:drift/drift.dart';

import 'habit_entry_table.dart';
import 'habit_table.dart';

part 'habit_database.g.dart';

/// The Habits domain database: habit definitions and per-day entries.
@DriftDatabase(tables: [Habits, HabitEntries])
class HabitDatabase extends _$HabitDatabase {
  HabitDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {},
      );
}