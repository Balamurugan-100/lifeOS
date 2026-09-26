import 'dart:io';

import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Regression coverage for the `onUpgrade` strategy.
///
/// Before this strategy existed, opening a *pre-existing* database file threw
/// "You've bumped the schema version ... but didn't provide a strategy for
/// schema updates", because drift only reaches `beforeOpen` on the
/// `wasCreated` path. Fresh in-memory databases never reproduce it, so the
/// migration is exercised here against a real v1 file on disk.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lifeos_tasks_migration');
    dbPath = '${tempDir.path}/tasks.db';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Writes the schema v1 shape of `tasks` (no priority/notes/category/
  /// repeat_interval/deleted_at), inserts one legacy row, and marks the file
  /// as version 1 so drift takes the upgrade path.
  Future<void> seedLegacyV1() async {
    final db = sqlite3.open(dbPath);
    db.execute('''
      CREATE TABLE tasks (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        due_date INTEGER NULL,
        position INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      INSERT INTO tasks (id, title, status, position, created_at, updated_at)
      VALUES ('legacy-1', 'Legacy task', 'outstanding', 0, 0, 0);
    ''');
    db.execute('PRAGMA user_version = 1;');
    db.close();
  }

  test('opens a pre-existing v1 file without throwing the upgrade error',
      () async {
    await seedLegacyV1();

    final database = TaskDatabase(openFileExecutor(dbPath));
    addTearDown(database.close);

    // A query forces drift to run beforeOpen/onUpgrade.
    final rows = await database.select(database.tasks).get();

    expect(rows, hasLength(1), reason: 'legacy row must survive the upgrade');
    expect(rows.single.title, 'Legacy task');
  });

  test('back-fills the columns added after v1', () async {
    await seedLegacyV1();

    final database = TaskDatabase(openFileExecutor(dbPath));
    addTearDown(database.close);

    final legacy = (await database.select(database.tasks).get()).single;

    expect(legacy.priority, 'medium', reason: 'back-filled with default');
    expect(legacy.repeatInterval, 'none', reason: 'back-filled with default');
    expect(legacy.notes, isNull);
    expect(legacy.category, isNull);
    expect(legacy.deletedAt, isNull);

    await database.into(database.tasks).insert(
          TasksCompanion.insert(
            id: 'fresh',
            title: 'Post-upgrade task',
            status: 'outstanding',
            position: 1,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    expect(await database.select(database.tasks).get(), hasLength(2));
  });
}
