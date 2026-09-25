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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        beforeOpen: (details) async {},
      );

  Future<void> ensureTables() async {
    await Migrator(this).createAll();
    await _seedCategories();
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
