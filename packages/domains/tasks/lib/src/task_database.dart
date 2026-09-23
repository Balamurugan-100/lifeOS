import 'package:drift/drift.dart';

import 'task_table.dart';

part 'task_database.g.dart';

/// The Tasks domain database: a single task list table (data-model.md).
@DriftDatabase(tables: [Tasks])
class TaskDatabase extends _$TaskDatabase {
  TaskDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// Drift's default keeps `created_at`/`updated_at` for the AuditFields mixin.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {},
      );
}