import 'package:drift/drift.dart';

part 'journal_database.g.dart';

@DataClassName('JournalEntryData')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entryDate => text()(); // yyyy-MM-dd
  IntColumn get moodScore => integer().withDefault(const Constant(3))();
  TextColumn get gratitude => text().nullable()();
  TextColumn get reflection => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [JournalEntries])
class JournalDatabase extends _$JournalDatabase {
  JournalDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
