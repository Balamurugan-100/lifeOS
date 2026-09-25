import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;

/// Drift table backing category monthly budgets.
@DataClassName('BudgetEntry')
class CategoryBudgets extends Table with AuditFields {
  TextColumn get id => text()();
  TextColumn get categoryId => text().named('category_id')();
  RealColumn get monthlyLimit => real().named('monthly_limit')();

  @override
  Set<Column> get primaryKey => {id};
}
