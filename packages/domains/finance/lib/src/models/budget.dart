/// Budget domain model for lifeos_finance.
library;

class CategoryBudget {
  const CategoryBudget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final double monthlyLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryBudget copyWith({
    double? monthlyLimit,
    DateTime? updatedAt,
  }) {
    return CategoryBudget(
      id: id,
      categoryId: categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
