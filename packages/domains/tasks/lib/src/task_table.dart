import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;

/// Drift table backing the `Task` domain entity (data-model.md).
///
/// `status` is stored as the enum name string, `due_date` is a nullable local
/// calendar date (epoch/null sentinel means "no due date"), and `position`
/// holds the manual ordering index. Audit fields are UTC (history.dart).
class Tasks extends Table with AuditFields {
  TextColumn get id => text()();

  TextColumn get title => text()();

  /// 'outstanding' | 'completed'
  TextColumn get status => text()();

  /// Local calendar date; null (stored as epoch) when undated.
  DateTimeColumn get dueDate => dateTime().nullable().named('due_date')();

  /// Manual ordering index for the task list.
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}