/// Transaction domain model for lifeos_finance.
library;

enum TransactionType {
  expense,
  income,
  transfer;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TransactionType.expense,
    );
  }
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.accountId,
    this.toAccountId,
    required this.type,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.note,
    this.isReconciliationAdjustment = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final String? toAccountId;
  final TransactionType type;
  final String categoryId;
  final double amount;
  final DateTime date;
  final String? note;
  final bool isReconciliationAdjustment;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinanceTransaction copyWith({
    String? accountId,
    String? toAccountId,
    TransactionType? type,
    String? categoryId,
    double? amount,
    DateTime? date,
    String? note,
    bool? isReconciliationAdjustment,
    DateTime? updatedAt,
  }) {
    return FinanceTransaction(
      id: id,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      isReconciliationAdjustment:
          isReconciliationAdjustment ?? this.isReconciliationAdjustment,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
