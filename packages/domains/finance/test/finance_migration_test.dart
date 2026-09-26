import 'dart:io';

import 'package:lifeos_finance/lifeos_finance.dart';
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
    tempDir = Directory.systemTemp.createTempSync('lifeos_finance_migration');
    dbPath = '${tempDir.path}/finance.db';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Writes the schema v1 shape of the three tables that gained `deleted_at`
  /// after v1, inserts one legacy account, and marks the file as version 1.
  void seedLegacyV1() {
    final db = sqlite3.open(dbPath);
    db.execute('''
      CREATE TABLE accounts (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        currency_symbol TEXT NOT NULL DEFAULT '₹',
        initial_balance REAL NOT NULL DEFAULT 0.0,
        color_hex TEXT NULL,
        icon_name TEXT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        last_reconciled_at INTEGER NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE finance_transactions (
        id TEXT NOT NULL PRIMARY KEY,
        account_id TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE category_budgets (
        id TEXT NOT NULL PRIMARY KEY,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      INSERT INTO accounts
        (id, name, type, created_at, updated_at)
      VALUES ('legacy-1', 'Legacy account', 'bank', 0, 0);
    ''');
    db.execute('PRAGMA user_version = 1;');
    db.close();
  }

  test('opens a pre-existing v1 file without throwing the upgrade error',
      () async {
    seedLegacyV1();

    final database = FinanceDatabase(openFileExecutor(dbPath));
    addTearDown(database.close);

    final rows = await database.select(database.accounts).get();

    expect(rows, hasLength(1), reason: 'legacy row must survive the upgrade');
    expect(rows.single.name, 'Legacy account');
    expect(rows.single.deletedAt, isNull, reason: 'column back-filled as null');
  });

  test('seeds predefined categories on upgrade', () async {
    seedLegacyV1();

    final database = FinanceDatabase(openFileExecutor(dbPath));
    addTearDown(database.close);

    final categories = await database.select(database.financeCategories).get();

    expect(categories, isNotEmpty,
        reason: 'default categories must be seeded during the upgrade');
  });
}
