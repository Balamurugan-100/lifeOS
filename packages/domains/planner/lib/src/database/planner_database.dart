import 'package:drift/drift.dart';

part 'planner_database.g.dart';

@DataClassName('TimeBlockData')
class TimeBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get date => text()();
  IntColumn get startMinute => integer()();
  IntColumn get durationMinutes => integer()();
  TextColumn get category => text().withDefault(const Constant('focus'))();
  TextColumn get linkedTaskId => text().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('#38BDF8'))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [TimeBlocks])
class PlannerDatabase extends _$PlannerDatabase {
  PlannerDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
