/// Reconciliation record model for lifeos_finance.
library;

class ReconciliationRecord {
  const ReconciliationRecord({
    required this.id,
    required this.accountId,
    required this.statementBalance,
    required this.calculatedBalanceBefore,
    required this.discrepancy,
    required this.adjustmentAmount,
    required this.reconciledAt,
  });

  final String id;
  final String accountId;
  final double statementBalance;
  final double calculatedBalanceBefore;
  final double discrepancy;
  final double adjustmentAmount;
  final DateTime reconciledAt;
}
