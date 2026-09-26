import 'dart:io';

import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Regression coverage for the `onUpgrade` strategy.
///
/// Drift only reaches `beforeOpen` on the `wasCreated` path, so a
/// schemaVersion 2 database without an `onUpgrade` strategy throws
/// "You've bumped the schema version ... but didn't provide a strategy for
/// schema updates" when opening a *pre-existing* file. In-memory tests never
/// reproduce it, so the upgrade path is exercised against a real v1 file here.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lifeos_habits_migration');
    dbPath = '${tempDir.path}/habits.db';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Writes the schema v1 shape of `habits` (no `deleted_at`), inserts one
  /// legacy row, and marks the file as version 1.
  void seedLegacyV1() {
    final db = sqlite3.open(dbPath);
    db.execute('''
      CREATE TABLE habits (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        schedule_type TEXT NOT NULL,
        days_of_week TEXT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      INSERT INTO habits
        (id, name, schedule_type, days_of_week, created_at, updated_at)
      VALUES ('legacy-1', 'Legacy habit', 'daily', NULL, 0, 0);
    ''');
    db.execute('PRAGMA user_version = 1;');
    db.close();
  }

  test('opens a pre-existing v1 file without throwing the upgrade error',
      () async {
    seedLegacyV1();

    final database = HabitDatabase(openFileExecutor(dbPath));
    addTearDown(database.close);

    final rows = await database.select(database.habits).get();

    expect(rows, hasLength(1), reason: 'legacy row must survive the upgrade');
    expect(rows.single.name, 'Legacy habit');
    expect(rows.single.deletedAt, isNull, reason: 'column back-filled as null');
  });
}
