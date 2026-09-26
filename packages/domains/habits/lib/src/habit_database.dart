import 'package:drift/drift.dart';

import 'habit_entry_table.dart';
import 'habit_table.dart';

part 'habit_database.g.dart';

/// The Habits domain database: habit definitions and per-day entries.
@DriftDatabase(tables: [Habits, HabitEntries])
class HabitDatabase extends _$HabitDatabase {
  HabitDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          await m.createAll();
          await _ensureColumnsExist();
        },
        beforeOpen: (details) async {
          await _ensureColumnsExist();
        },
      );

  Future<void> ensureTables() async {
    await Migrator(this).createAll();
    await _ensureColumnsExist();
  }

  Future<void> _ensureColumnsExist() async {
    final existingColumns = <String>{};
    try {
      final rows = await customSelect('PRAGMA table_info(habits)').get();
      for (final row in rows) {
        existingColumns.add(row.read<String>('name'));
      }
    } catch (_) {}

    if (!existingColumns.contains('deleted_at')) {
      try {
        await customStatement("ALTER TABLE habits ADD COLUMN deleted_at INTEGER;");
      } catch (_) {}
    }
  }
}