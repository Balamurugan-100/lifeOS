import 'package:drift/drift.dart';

import '../tables/accounts_table.dart';
import '../tables/budgets_table.dart';
import '../tables/categories_table.dart';
import '../tables/reconciliations_table.dart';
import '../tables/transactions_table.dart';
import 'default_categories.dart';

part 'finance_database.g.dart';

/// The Finance domain database (accounts, categories, transactions, budgets, reconciliations).
@DriftDatabase(tables: [
  Accounts,
  FinanceCategories,
  FinanceTransactions,
  CategoryBudgets,
  ReconciliationRecords,
])
class FinanceDatabase extends _$FinanceDatabase {
  FinanceDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          await m.createAll();
          await _ensureColumnsExist();
          await _seedCategories();
        },
        beforeOpen: (details) async {
          await _ensureColumnsExist();
        },
      );

  Future<void> ensureTables() async {
    await Migrator(this).createAll();
    await _ensureColumnsExist();
    await _seedCategories();
  }

  Future<void> _ensureColumnsExist() async {
    for (final table in ['accounts', 'finance_transactions', 'category_budgets']) {
      final existingColumns = <String>{};
      try {
        final rows = await customSelect('PRAGMA table_info($table)').get();
        for (final row in rows) {
          existingColumns.add(row.read<String>('name'));
        }
      } catch (_) {}

      if (!existingColumns.contains('deleted_at')) {
        try {
          await customStatement("ALTER TABLE $table ADD COLUMN deleted_at INTEGER;");
        } catch (_) {}
      }
    }
  }

  Future<void> _seedCategories() async {
    for (final cat in defaultPredefinedCategories) {
      await into(financeCategories).insertOnConflictUpdate(
        FinanceCategoriesCompanion.insert(
          id: cat.id,
          name: cat.name,
          type: cat.type.name,
          iconName: cat.iconName,
          colorHex: cat.colorHex,
          isPredefined: const Value(true),
          createdAt: cat.createdAt,
        ),
      );
    }
  }
}
