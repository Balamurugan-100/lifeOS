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

/// Thrown by [FinanceRepository.deleteCategory] when transactions still point
/// at the category.
///
/// Deleting anyway would leave those transactions with a `categoryId` that
/// resolves to nothing, so the count is surfaced to the user instead and they
/// reassign or clear the transactions first.
class CategoryInUseException implements Exception {
  const CategoryInUseException(this.categoryId, this.transactionCount);

  final String categoryId;
  final int transactionCount;

  @override
  String toString() => 'CategoryInUseException: category "$categoryId" is used '
      'by $transactionCount transaction(s); reassign or clear them first.';
}

/// Thrown when a category of the same [type] already answers to that name.
class CategoryNameTakenException implements Exception {
  const CategoryNameTakenException(this.name, this.type);

  final String name;
  final CategoryType type;

  @override
  String toString() => 'CategoryNameTakenException: a ${type.name} category '
      'named "$name" already exists.';
}
