import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../database/gamification_database.dart' hide XpTransaction;
import '../models/achievement.dart';
import '../models/daily_quest.dart';
import '../models/life_balance.dart';
import '../models/life_xp.dart';

class GamificationRepository {
  GamificationRepository(this._db);

  final GamificationDatabase _db;
  static const String _userKey = 'current_user';

  Future<LifeXpProfile> getProfile() async {
    final today = isoDate(todayLocal());
    final row = await (_db.select(_db.userXp)
          ..where((t) => t.id.equals(_userKey)))
        .getSingleOrNull();

    if (row == null) {
      final now = DateTime.now();
      await _db.into(_db.userXp).insert(
            UserXpCompanion.insert(
              id: _userKey,
              totalXp: const Value(0),
              streakBonusXp: const Value(0),
              todayXp: const Value(0),
              lastUpdatedDate: today,
              updatedAt: now,
            ),
          );
      return LifeXpProfile(
        totalXp: 0,
        streakBonusXp: 0,
        todayXp: 0,
        lastUpdated: now,
      );
    }

    final isNewDay = row.lastUpdatedDate != today;
    final currentTodayXp = isNewDay ? 0 : row.todayXp;

    return LifeXpProfile(
      totalXp: row.totalXp,
      streakBonusXp: row.streakBonusXp,
      todayXp: currentTodayXp,
      lastUpdated: row.updatedAt,
    );
  }

  Future<LifeXpProfile> addXp(
    int amount, {
    required String domain,
    required String reason,
  }) async {
    final today = isoDate(todayLocal());
    final current = await getProfile();
    final newTotal = current.totalXp + amount;
    final newToday = current.todayXp + amount;
    final now = DateTime.now();

    await (_db.update(_db.userXp)..where((t) => t.id.equals(_userKey))).write(
      UserXpCompanion(
        totalXp: Value(newTotal),
        todayXp: Value(newToday),
        lastUpdatedDate: Value(today),
        updatedAt: Value(now),
      ),
    );

    await _db.into(_db.xpTransactions).insert(
          XpTransactionsCompanion.insert(
            id: 'xp_${now.millisecondsSinceEpoch}_$amount',
            amount: amount,
            domain: domain,
            reason: reason,
            timestamp: now,
          ),
        );

    return current.copyWith(
      totalXp: newTotal,
      todayXp: newToday,
      lastUpdated: now,
    );
  }

  Future<List<XpTransaction>> getRecentTransactions({int limit = 20}) async {
    final rows = await (_db.select(_db.xpTransactions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();

    return rows
        .map((r) => XpTransaction(
              id: r.id,
              amount: r.amount,
              domain: r.domain,
              reason: r.reason,
              timestamp: r.timestamp,
            ))
        .toList();
  }

  Future<List<Achievement>> getAchievements({
    int tasksCompleted = 0,
    int habitStreak = 0,
    int focusMins = 0,
    int journalEntries = 0,
    int goalsCompleted = 0,
    int notesCount = 0,
    int financeTxCount = 0,
  }) async {
    final unlockedRows = await _db.select(_db.unlockedAchievements).get();
    final unlockedMap = {
      for (final r in unlockedRows) r.id: r.unlockedAt,
    };

    final definitions = [
      // 1. Tasks
      Achievement(
        id: 'task_starter',
        title: 'First Step',
        description: 'Complete your first task',
        icon: '🌱',
        domain: 'tasks',
        tier: AchievementTier.bronze,
        targetValue: 1,
        currentValue: tasksCompleted,
        isUnlocked: tasksCompleted >= 1,
        unlockedAt: unlockedMap['task_starter'],
        xpReward: 50,
      ),
      Achievement(
        id: 'task_warrior',
        title: 'Task Warrior',
        description: 'Complete 10 tasks',
        icon: '⚔️',
        domain: 'tasks',
        tier: AchievementTier.silver,
        targetValue: 10,
        currentValue: tasksCompleted,
        isUnlocked: tasksCompleted >= 10,
        unlockedAt: unlockedMap['task_warrior'],
        xpReward: 150,
      ),
      Achievement(
        id: 'task_master',
        title: 'Execution Master',
        description: 'Complete 50 tasks',
        icon: '👑',
        domain: 'tasks',
        tier: AchievementTier.gold,
        targetValue: 50,
        currentValue: tasksCompleted,
        isUnlocked: tasksCompleted >= 50,
        unlockedAt: unlockedMap['task_master'],
        xpReward: 500,
      ),

      // 2. Habits
      Achievement(
        id: 'habit_spark',
        title: 'Habit Spark',
        description: 'Achieve a 3-day habit streak',
        icon: '🔥',
        domain: 'habits',
        tier: AchievementTier.bronze,
        targetValue: 3,
        currentValue: habitStreak,
        isUnlocked: habitStreak >= 3,
        unlockedAt: unlockedMap['habit_spark'],
        xpReward: 75,
      ),
      Achievement(
        id: 'habit_unbroken',
        title: 'Unbroken Rhythm',
        description: 'Achieve a 7-day habit streak',
        icon: '⚡',
        domain: 'habits',
        tier: AchievementTier.silver,
        targetValue: 7,
        currentValue: habitStreak,
        isUnlocked: habitStreak >= 7,
        unlockedAt: unlockedMap['habit_unbroken'],
        xpReward: 200,
      ),
      Achievement(
        id: 'habit_legend',
        title: 'Habit Legend',
        description: 'Achieve a 21-day habit transformation',
        icon: '🌟',
        domain: 'habits',
        tier: AchievementTier.gold,
        targetValue: 21,
        currentValue: habitStreak,
        isUnlocked: habitStreak >= 21,
        unlockedAt: unlockedMap['habit_legend'],
        xpReward: 600,
      ),

      // 3. Focus
      Achievement(
        id: 'focus_flow',
        title: 'Deep Flow State',
        description: 'Complete 60 focus minutes',
        icon: '⏱️',
        domain: 'focus',
        tier: AchievementTier.bronze,
        targetValue: 60,
        currentValue: focusMins,
        isUnlocked: focusMins >= 60,
        unlockedAt: unlockedMap['focus_flow'],
        xpReward: 100,
      ),
      Achievement(
        id: 'focus_zenith',
        title: 'Zenith of Focus',
        description: 'Complete 300 focus minutes',
        icon: '🧘',
        domain: 'focus',
        tier: AchievementTier.silver,
        targetValue: 300,
        currentValue: focusMins,
        isUnlocked: focusMins >= 300,
        unlockedAt: unlockedMap['focus_zenith'],
        xpReward: 350,
      ),

      // 4. Mind & Journal
      Achievement(
        id: 'mindful_presence',
        title: 'Mindful Presence',
        description: 'Log 5 daily reflections',
        icon: '🌅',
        domain: 'journal',
        tier: AchievementTier.bronze,
        targetValue: 5,
        currentValue: journalEntries,
        isUnlocked: journalEntries >= 5,
        unlockedAt: unlockedMap['mindful_presence'],
        xpReward: 80,
      ),

      // 5. Wealth & Discipline
      Achievement(
        id: 'wealth_guard',
        title: 'Financial Sentinel',
        description: 'Track 10 transactions and stay mindful of budget',
        icon: '💰',
        domain: 'finance',
        tier: AchievementTier.bronze,
        targetValue: 10,
        currentValue: financeTxCount,
        isUnlocked: financeTxCount >= 10,
        unlockedAt: unlockedMap['wealth_guard'],
        xpReward: 120,
      ),

      // 6. Growth & Milestones
      Achievement(
        id: 'goal_achiever',
        title: 'Milestone Conqueror',
        description: 'Complete your first OKR Goal',
        icon: '🎯',
        domain: 'goals',
        tier: AchievementTier.silver,
        targetValue: 1,
        currentValue: goalsCompleted,
        isUnlocked: goalsCompleted >= 1,
        unlockedAt: unlockedMap['goal_achiever'],
        xpReward: 250,
      ),

      // 7. Knowledge & Notes
      Achievement(
        id: 'knowledge_vault',
        title: 'Second Brain',
        description: 'Create 5 Markdown notes and documents',
        icon: '📜',
        domain: 'notes',
        tier: AchievementTier.bronze,
        targetValue: 5,
        currentValue: notesCount,
        isUnlocked: notesCount >= 5,
        unlockedAt: unlockedMap['knowledge_vault'],
        xpReward: 90,
      ),
    ];

    // Automatically record newly unlocked achievements in database
    for (final ach in definitions) {
      if (ach.isUnlocked && !unlockedMap.containsKey(ach.id)) {
        final now = DateTime.now();
        await _db.into(_db.unlockedAchievements).insert(
              UnlockedAchievementsCompanion.insert(
                id: ach.id,
                unlockedAt: now,
              ),
            );
        await addXp(
          ach.xpReward,
          domain: ach.domain,
          reason: 'Achievement Unlocked: ${ach.title}',
        );
      }
    }

    return definitions;
  }

  Future<List<DailyQuest>> getDailyQuests({
    int tasksDoneToday = 0,
    int habitsDoneToday = 0,
    int focusMinsToday = 0,
    bool moodLoggedToday = false,
  }) async {
    final today = isoDate(todayLocal());
    final claimedRows = await (_db.select(_db.claimedQuests)
          ..where((t) => t.date.equals(today)))
        .get();

    final claimedIds = {for (final r in claimedRows) r.questId};

    return [
      DailyQuest(
        id: 'quest_tasks',
        title: 'Daily Execution',
        description: 'Complete at least 2 tasks today',
        icon: '⚡',
        domain: 'tasks',
        targetCount: 2,
        currentCount: tasksDoneToday,
        xpReward: 40,
        isCompleted: tasksDoneToday >= 2,
        isClaimed: claimedIds.contains('quest_tasks'),
      ),
      DailyQuest(
        id: 'quest_habits',
        title: 'Habit Momentum',
        description: 'Check off at least 2 habits today',
        icon: '🔥',
        domain: 'habits',
        targetCount: 2,
        currentCount: habitsDoneToday,
        xpReward: 40,
        isCompleted: habitsDoneToday >= 2,
        isClaimed: claimedIds.contains('quest_habits'),
      ),
      DailyQuest(
        id: 'quest_focus_mood',
        title: 'Mind & Focus Calibration',
        description: 'Log 25 mins of deep work or daily reflection',
        icon: '🧘',
        domain: 'focus',
        targetCount: 1,
        currentCount: (focusMinsToday >= 25 || moodLoggedToday) ? 1 : 0,
        xpReward: 35,
        isCompleted: focusMinsToday >= 25 || moodLoggedToday,
        isClaimed: claimedIds.contains('quest_focus_mood'),
      ),
    ];
  }

  Future<void> claimQuest(DailyQuest quest) async {
    if (!quest.isCompleted || quest.isClaimed) return;
    final today = isoDate(todayLocal());
    final id = '${quest.id}_$today';

    await _db.into(_db.claimedQuests).insert(
          ClaimedQuestsCompanion.insert(
            id: id,
            questId: quest.id,
            date: today,
            claimedAt: DateTime.now(),
          ),
        );

    await addXp(
      quest.xpReward,
      domain: quest.domain,
      reason: 'Daily Quest Claimed: ${quest.title}',
    );
  }

  LifeBalance calculateLifeBalance({
    int tasksCount = 0,
    int focusMins = 0,
    int habitStreak = 0,
    int habitsDone = 0,
    int financeTxCount = 0,
    int journalEntries = 0,
    int activeGoals = 0,
    int notesCount = 0,
  }) {
    // 1. Productivity: based on tasks & deep work
    final prodScore = ((tasksCount * 15.0) + (focusMins / 2.0)).clamp(10.0, 100.0);

    // 2. Discipline: based on habit streaks & habits done
    final discScore = ((habitStreak * 12.0) + (habitsDone * 10.0)).clamp(10.0, 100.0);

    // 3. Wealth: based on transaction tracking & accounts
    final wealthScore = (financeTxCount > 0 ? 50.0 + (financeTxCount * 5.0) : 20.0).clamp(10.0, 100.0);

    // 4. Mind: based on journal check-ins & mood ratings
    final mindScore = (journalEntries > 0 ? 40.0 + (journalEntries * 12.0) : 15.0).clamp(10.0, 100.0);

    // 5. Growth: based on OKR goals & markdown knowledge notes
    final growthScore = ((activeGoals * 25.0) + (notesCount * 15.0)).clamp(10.0, 100.0);

    return LifeBalance(
      productivity: prodScore,
      discipline: discScore,
      wealth: wealthScore,
      mind: mindScore,
      growth: growthScore,
    );
  }
}
