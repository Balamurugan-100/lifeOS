import 'package:drift/drift.dart';

part 'review_database.g.dart';

@DataClassName('WeeklyReviewData')
class WeeklyReviews extends Table {
  TextColumn get id => text()();
  TextColumn get weekStartDate => text()();
  IntColumn get rating => integer().withDefault(const Constant(4))();
  TextColumn get biggestWin => text().withDefault(const Constant(''))();
  TextColumn get challengeOrLesson => text().withDefault(const Constant(''))();
  TextColumn get bigBets => text().withDefault(const Constant('[]'))();
  IntColumn get totalTasksCompleted => integer().withDefault(const Constant(0))();
  IntColumn get totalHabitCheckins => integer().withDefault(const Constant(0))();
  IntColumn get totalFocusMinutes => integer().withDefault(const Constant(0))();
  RealColumn get netSavings => real().withDefault(const Constant(0.0))();
  RealColumn get averageMood => real().withDefault(const Constant(4.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [WeeklyReviews])
class ReviewDatabase extends _$ReviewDatabase {
  ReviewDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );

  Future<void> ensureTables() async => Migrator(this).createAll();
}
