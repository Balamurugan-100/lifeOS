import 'package:lifeos_gamification/lifeos_gamification.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  group('Gamification Repository Tests', () {
    late GamificationDatabase db;
    late GamificationRepository repo;

    setUp(() async {
      db = GamificationDatabase(openInMemoryExecutor());
      await db.ensureTables();
      repo = GamificationRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('starts at Level 1 with 0 XP and gains levels with XP additions',
        () async {
      final initial = await repo.getProfile();
      expect(initial.level, equals(1));
      expect(initial.totalXp, equals(0));
      expect(initial.rankTitle, equals('Novice Explorer'));

      // Add 200 XP (threshold for Lv 3 is (3-1)^2 * 50 = 200)
      final updated = await repo.addXp(
        200,
        domain: 'tasks',
        reason: 'Completed tasks streak',
      );

      expect(updated.totalXp, equals(200));
      expect(updated.level, equals(3));
      expect(updated.rankTitle, equals('Routine Builder'));

      final txs = await repo.getRecentTransactions();
      expect(txs.length, equals(1));
      expect(txs.first.amount, equals(200));
      expect(txs.first.reason, equals('Completed tasks streak'));
    });

    test('evaluates achievements and unlocks rewards', () async {
      final achievements = await repo.getAchievements(
        tasksCompleted: 15,
        habitStreak: 8,
        focusMins: 120,
        journalEntries: 6,
        goalsCompleted: 1,
        notesCount: 5,
        financeTxCount: 12,
      );

      expect(achievements.any((a) => a.id == 'task_starter' && a.isUnlocked),
          isTrue);
      expect(achievements.any((a) => a.id == 'task_warrior' && a.isUnlocked),
          isTrue);
      expect(achievements.any((a) => a.id == 'habit_unbroken' && a.isUnlocked),
          isTrue);
      expect(achievements.any((a) => a.id == 'focus_flow' && a.isUnlocked),
          isTrue);
      expect(achievements.any((a) => a.id == 'mindful_presence' && a.isUnlocked),
          isTrue);
      expect(achievements.any((a) => a.id == 'goal_achiever' && a.isUnlocked),
          isTrue);

      final profile = await repo.getProfile();
      expect(profile.totalXp, greaterThan(0)); // XP granted for achievements
    });

    test('tracks and claims daily quests', () async {
      final quests = await repo.getDailyQuests(
        tasksDoneToday: 3,
        habitsDoneToday: 2,
        focusMinsToday: 30,
        moodLoggedToday: true,
      );

      expect(quests.length, equals(3));
      expect(quests.every((q) => q.isCompleted), isTrue);
      expect(quests.every((q) => !q.isClaimed), isTrue);

      final initialProfile = await repo.getProfile();
      final initialXp = initialProfile.totalXp;

      // Claim first quest
      await repo.claimQuest(quests.first);

      final updatedQuests = await repo.getDailyQuests(
        tasksDoneToday: 3,
        habitsDoneToday: 2,
        focusMinsToday: 30,
        moodLoggedToday: true,
      );

      expect(updatedQuests.first.isClaimed, isTrue);

      final updatedProfile = await repo.getProfile();
      expect(updatedProfile.totalXp, equals(initialXp + quests.first.xpReward));
    });

    test('calculates 5-dimensional Life Balance radar scores', () {
      final balance = repo.calculateLifeBalance(
        tasksCount: 4,
        focusMins: 60,
        habitStreak: 7,
        habitsDone: 3,
        financeTxCount: 5,
        journalEntries: 3,
        activeGoals: 2,
        notesCount: 4,
      );

      expect(balance.productivity, greaterThanOrEqualTo(50));
      expect(balance.discipline, greaterThanOrEqualTo(50));
      expect(balance.wealth, greaterThanOrEqualTo(50));
      expect(balance.mind, greaterThanOrEqualTo(50));
      expect(balance.growth, greaterThanOrEqualTo(50));
      expect(balance.overallScore, greaterThan(50));
      expect(balance.harmonyRating, isNotEmpty);
    });

    test('GamificationModule generates valid DomainSummary', () async {
      final module = GamificationModule(db);
      final emptySummary = await module.buildSummary();
      expect(emptySummary.isEmpty, isTrue);

      await repo.addXp(150, domain: 'tasks', reason: 'Task execution');
      final activeSummary = await module.buildSummary();
      expect(activeSummary.isEmpty, isFalse);
      expect(activeSummary.counts['level'], equals(2));
      expect(activeSummary.counts['total xp'], equals(150));
      expect(activeSummary.highlighted.isNotEmpty, isTrue);
    });
  });
}
