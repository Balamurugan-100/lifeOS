import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;

/// Drift table backing the `FinanceTransaction` domain entity.
@DataClassName('TransactionEntry')
class FinanceTransactions extends Table with AuditFields {
  TextColumn get id => text()();
  TextColumn get accountId => text().named('account_id')();
  TextColumn get toAccountId => text().nullable().named('to_account_id')();
  TextColumn get type => text()(); // 'expense' | 'income' | 'transfer'
  TextColumn get categoryId => text().named('category_id')();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get isReconciliationAdjustment => boolean()
      .withDefault(const Constant(false))
      .named('is_reconciliation_adjustment')();

  @override
  Set<Column> get primaryKey => {id};
}
