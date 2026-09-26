import 'package:drift/drift.dart';

part 'wellness_database.g.dart';

@DataClassName('WellnessLogData')
class WellnessLogs extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()();
  IntColumn get sleepDurationMinutes => integer().withDefault(const Constant(420))();
  IntColumn get sleepQualityScore => integer().withDefault(const Constant(4))();
  IntColumn get energyScore => integer().withDefault(const Constant(4))();
  IntColumn get stepCount => integer().withDefault(const Constant(0))();
  IntColumn get waterMl => integer().withDefault(const Constant(2000))();
  TextColumn get factors => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [WellnessLogs])
class WellnessDatabase extends _$WellnessDatabase {
  WellnessDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
