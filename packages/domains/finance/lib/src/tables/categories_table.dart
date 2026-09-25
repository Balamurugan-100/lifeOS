import 'package:drift/drift.dart';

/// Drift table backing the `FinanceCategory` domain entity.
@DataClassName('CategoryEntry')
class FinanceCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'expense' | 'income'
  TextColumn get iconName => text().named('icon_name')();
  TextColumn get colorHex => text().named('color_hex')();
  BoolColumn get isPredefined =>
      boolean().withDefault(const Constant(true)).named('is_predefined')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
