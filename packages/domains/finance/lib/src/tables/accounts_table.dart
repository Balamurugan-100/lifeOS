import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;

/// Drift table backing the `Account` domain entity.
@DataClassName('AccountEntry')
class Accounts extends Table with AuditFields {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get currencySymbol =>
      text().withDefault(const Constant('₹')).named('currency_symbol')();
  RealColumn get initialBalance =>
      real().withDefault(const Constant(0.0)).named('initial_balance')();
  TextColumn get colorHex => text().nullable().named('color_hex')();
  TextColumn get iconName => text().nullable().named('icon_name')();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false)).named('is_archived')();
  DateTimeColumn get lastReconciledAt =>
      dateTime().nullable().named('last_reconciled_at')();

  @override
  Set<Column> get primaryKey => {id};
}
