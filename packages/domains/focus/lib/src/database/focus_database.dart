import 'package:drift/drift.dart';

part 'focus_database.g.dart';

@DataClassName('FocusSessionData')
class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get taskTitle => text().nullable()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get mode => text().withDefault(const Constant('pomodoro'))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [FocusSessions])
class FocusDatabase extends _$FocusDatabase {
  FocusDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
