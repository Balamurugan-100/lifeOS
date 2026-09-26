import 'package:drift/drift.dart';

part 'rituals_database.g.dart';

@DataClassName('RitualEntry')
class RitualEntries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get description => text().nullable()();
  TextColumn get iconName => text().withDefault(const Constant('routine'))();
  TextColumn get colorHex => text().withDefault(const Constant('#38BDF8'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get streak => integer().withDefault(const Constant(0))();
  TextColumn get lastCompletedDate => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RitualStepEntry')
class RitualStepEntries extends Table {
  TextColumn get id => text()();
  TextColumn get ritualId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(5))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RitualExecutionLog')
class RitualExecutionLogs extends Table {
  TextColumn get id => text()();
  TextColumn get ritualId => text()();
  TextColumn get date => text()();
  TextColumn get completedStepIds => text().withDefault(const Constant('[]'))();
  BoolColumn get isFullCompletion => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [RitualEntries, RitualStepEntries, RitualExecutionLogs])
class RitualsDatabase extends _$RitualsDatabase {
  RitualsDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
