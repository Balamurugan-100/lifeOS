import 'dart:async';

import 'package:drift/drift.dart';

import 'task_category_table.dart';
import 'task_table.dart';
import 'time_session_table.dart';

part 'task_database.g.dart';

/// The Tasks domain database: the task list, its editable category registry,
/// and tracked work sessions.
@DriftDatabase(tables: [Tasks, TimeSessions, TaskCategories])
class TaskDatabase extends _$TaskDatabase {
  TaskDatabase(super.e);

  @override
  int get schemaVersion => 4;

  /// Drift's default keeps `created_at`/`updated_at` for the AuditFields mixin.
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
      final rows = await customSelect('PRAGMA table_info(tasks)').get();
      for (final row in rows) {
        existingColumns.add(row.read<String>('name'));
      }
    } catch (_) {}

    if (!existingColumns.contains('priority')) {
      try {
        await customStatement(
            "ALTER TABLE tasks ADD COLUMN priority TEXT DEFAULT 'medium';");
      } catch (_) {}
    }
    if (!existingColumns.contains('notes')) {
      try {
        await customStatement("ALTER TABLE tasks ADD COLUMN notes TEXT;");
      } catch (_) {}
    }
    if (!existingColumns.contains('category')) {
      try {
        await customStatement("ALTER TABLE tasks ADD COLUMN category TEXT;");
      } catch (_) {}
    }
    if (!existingColumns.contains('repeat_interval')) {
      try {
        await customStatement(
            "ALTER TABLE tasks ADD COLUMN repeat_interval TEXT DEFAULT 'none';");
      } catch (_) {}
    }
    if (!existingColumns.contains('deleted_at')) {
      try {
        await customStatement("ALTER TABLE tasks ADD COLUMN deleted_at INTEGER;");
      } catch (_) {}
    }
  }
}