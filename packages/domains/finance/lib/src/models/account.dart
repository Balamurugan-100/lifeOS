/// Domain models for lifeos_finance.
library;

enum AccountType {
  bank,
  cash,
  credit,
  savings,
  investment;

  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AccountType.bank,
    );
  }
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.currencySymbol = '₹',
    this.initialBalance = 0.0,
    this.currentBalance = 0.0,
    this.colorHex,
    this.iconName,
    this.isArchived = false,
    this.lastReconciledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currencySymbol;
  final double initialBalance;
  final double currentBalance;
  final String? colorHex;
  final String? iconName;
  final bool isArchived;
  final DateTime? lastReconciledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account copyWith({
    String? name,
    AccountType? type,
    String? currencySymbol,
    double? initialBalance,
    double? currentBalance,
    String? colorHex,
    String? iconName,
    bool? isArchived,
    DateTime? lastReconciledAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      isArchived: isArchived ?? this.isArchived,
      lastReconciledAt: lastReconciledAt ?? this.lastReconciledAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
