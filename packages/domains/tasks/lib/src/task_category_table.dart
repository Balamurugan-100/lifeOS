import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;

/// Drift table backing the `TaskCategory` domain entity: the editable
/// registry of category names a task may be filed under.
///
/// Tasks keep storing the category as a plain name string on
/// `Tasks.category`, so this table is the source of truth for *which* names
/// exist (and how they are coloured) rather than for the task→category link
/// itself. That keeps existing task rows and the export format untouched.
@DataClassName('TaskCategoryEntry')
class TaskCategories extends Table with AuditFields {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorHex => text().named('color_hex').withDefault(
        const Constant('#5FA8A0'),
      )();

  @override
  Set<Column> get primaryKey => {id};
}
