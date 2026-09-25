import 'package:drift/drift.dart';

part 'goal_database.g.dart';

@DataClassName('GoalData')
class GoalsTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant('personal'))();
  TextColumn get status => text().withDefault(const Constant('inProgress'))();
  RealColumn get targetValue => real().withDefault(const Constant(100.0))();
  RealColumn get currentValue => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().withDefault(const Constant('%'))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get linkedHabitId => text().nullable()();
  TextColumn get linkedTaskId => text().nullable()();
  TextColumn get milestones => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [GoalsTable])
class GoalDatabase extends _$GoalDatabase {
  GoalDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
