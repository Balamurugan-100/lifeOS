/// Category domain model for lifeos_finance.
library;

enum CategoryType {
  expense,
  income;

  static CategoryType fromString(String value) {
    return CategoryType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CategoryType.expense,
    );
  }
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.colorHex,
    this.isPredefined = true,
    required this.createdAt,
  });

  final String id;
  final String name;
  final CategoryType type;
  final String iconName;
  final String colorHex;
  final bool isPredefined;
  final DateTime createdAt;

  FinanceCategory copyWith({
    String? name,
    CategoryType? type,
    String? iconName,
    String? colorHex,
    bool? isPredefined,
  }) {
    return FinanceCategory(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isPredefined: isPredefined ?? this.isPredefined,
      createdAt: createdAt,
    );
  }
}
