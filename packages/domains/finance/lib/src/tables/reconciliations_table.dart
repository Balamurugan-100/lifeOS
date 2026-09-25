import 'package:drift/drift.dart';

/// Drift table backing reconciliation audit logs.
@DataClassName('ReconciliationEntry')
class ReconciliationRecords extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().named('account_id')();
  RealColumn get statementBalance => real().named('statement_balance')();
  RealColumn get calculatedBalanceBefore =>
      real().named('calculated_balance_before')();
  RealColumn get discrepancy => real()();
  RealColumn get adjustmentAmount => real().named('adjustment_amount')();
  DateTimeColumn get reconciledAt => dateTime().named('reconciled_at')();

  @override
  Set<Column> get primaryKey => {id};
}
