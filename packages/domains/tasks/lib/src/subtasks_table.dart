import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show AuditFields;
import 'task_table.dart';

class Subtasks extends Table with AuditFields {
  TextColumn get id => text()();

  TextColumn get taskId => text().references(Tasks, #id)();

  TextColumn get title => text()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
