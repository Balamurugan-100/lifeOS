import 'package:drift/drift.dart';

part 'gamification_database.g.dart';

class UserXp extends Table {
  TextColumn get id => text()();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get streakBonusXp => integer().withDefault(const Constant(0))();
  IntColumn get todayXp => integer().withDefault(const Constant(0))();
  TextColumn get lastUpdatedDate => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class XpTransactions extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()();
  TextColumn get domain => text()();
  TextColumn get reason => text()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class UnlockedAchievements extends Table {
  TextColumn get id => text()();
  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ClaimedQuests extends Table {
  TextColumn get id => text()();
  TextColumn get questId => text()();
  TextColumn get date => text()();
  DateTimeColumn get claimedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  UserXp,
  XpTransactions,
  UnlockedAchievements,
  ClaimedQuests,
])
class GamificationDatabase extends _$GamificationDatabase {
  GamificationDatabase(super.e);

  @override
  int get schemaVersion => 1;

  Future<void> ensureTables() async {
    final m = createMigrator();
    for (final table in allTables) {
      await m.createTable(table).catchError((_) {});
    }
  }
}
