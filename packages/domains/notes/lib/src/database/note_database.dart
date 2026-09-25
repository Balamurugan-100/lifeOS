import 'package:drift/drift.dart';

part 'note_database.g.dart';

@DataClassName('NoteData')
class NotesTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('Untitled'))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get folder => text().withDefault(const Constant('General'))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [NotesTable])
class NoteDatabase extends _$NoteDatabase {
  NoteDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
