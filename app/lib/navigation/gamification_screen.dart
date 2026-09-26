import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_gamification/lifeos_gamification.dart';

import '../app.dart';
import '../theme/theme_controller.dart';

final gamificationDataProvider = FutureProvider.autoDispose((ref) async {
  final repo = await ref.watch(gamificationRepositoryProvider.future);
  final taskRepo = await ref.watch(taskRepositoryProvider.future);
  final habitRepo = await ref.watch(habitRepositoryProvider.future);
  final financeRepo = await ref.watch(financeRepositoryProvider.future);
  final journalRepo = await ref.watch(journalRepositoryProvider.future);
  final focusRepo = await ref.watch(focusRepositoryProvider.future);
  final goalRepo = await ref.watch(goalRepositoryProvider.future);
  final noteRepo = await ref.watch(notesRepositoryProvider.future);

  final today = todayLocal();
  final allTasks = await taskRepo.all();
  final tasksDone = allTasks.where((t) => t.isCompleted).length;
  final tasksDoneToday = allTasks.where((t) => t.isCompleted && (t.dueDate == null || isSameDay(t.dueDate!, today))).length;

  final allHabits = await habitRepo.all();
  final entries = await habitRepo.allEntries();
  final habitsDoneToday = entries.where((e) => isSameDay(e.date, today)).length;
  final habitStreak = entries.isNotEmpty ? (entries.length / (allHabits.isEmpty ? 1 : allHabits.length)).ceil() : 0;

  final txs = await financeRepo.getTransactions();

  final journalEntries = await journalRepo.getAllEntries();
  final moodLoggedToday = journalEntries.any((j) {
    final parsed = parseIsoDate(j.date);
    return parsed != null && isSameDay(parsed, today);
  });

  final focusSessions = await focusRepo.getAllSessions();
  final totalFocusMins = focusSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
  final focusMinsToday = focusSessions
      .where((s) => isSameDay(s.completedAt, today))
      .fold<int>(0, (sum, s) => sum + s.durationMinutes);

  final goals = await goalRepo.getAllGoals();
  final goalsDone = goals.where((g) => g.isCompleted).length;

  final notes = await noteRepo.getAllNotes();

  // Calculate achievements
  final achievements = await repo.getAchievements(
    tasksCompleted: tasksDone,
    habitStreak: habitStreak,
    focusMins: totalFocusMins,
    journalEntries: journalEntries.length,
    goalsCompleted: goalsDone,
    notesCount: notes.length,
    financeTxCount: txs.length,
  );

  // Auto-sync daily quests and auto-claim completed ones for effortless play
  final quests = await repo.getDailyQuests(
    tasksDoneToday: tasksDoneToday > 0 ? tasksDoneToday : (tasksDone > 0 ? 1 : 0),
    habitsDoneToday: habitsDoneToday > 0 ? habitsDoneToday : (entries.isNotEmpty ? 1 : 0),
    focusMinsToday: focusMinsToday > 0 ? focusMinsToday : (totalFocusMins > 0 ? 15 : 0),
    moodLoggedToday: moodLoggedToday || journalEntries.isNotEmpty,
  );

  // Auto-award XP for newly completed unclaimed quests
  for (final q in quests) {
    if (q.isCompleted && !q.isClaimed) {
      await repo.claimQuest(q);
    }
  }

  final profile = await repo.getProfile();

  final balance = repo.calculateLifeBalance(
    tasksCount: tasksDone,
    focusMins: totalFocusMins,
    habitStreak: habitStreak,
    habitsDone: entries.length,
    financeTxCount: txs.length,
    journalEntries: journalEntries.length,
    activeGoals: goals.length,
    notesCount: notes.length,
  );

  final recentTxs = await repo.getRecentTransactions(limit: 15);

  return (
    profile: profile,
    achievements: achievements,
    quests: quests,
    balance: balance,
    recentTxs: recentTxs,
    tasksDoneToday: tasksDoneToday,
    habitsDoneToday: habitsDoneToday,
    focusMinsToday: focusMinsToday,
    moodLoggedToday: moodLoggedToday,
  );
});

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});

  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen> {
  int _selectedTab = 0; // 0: Daily Goals & Quests, 1: Badges & Milestones, 2: Life Radar, 3: XP Log
  String _badgeFilter = 'all'; // 'all', 'unlocked', 'locked'

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(gamificationDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              '🎮 LifeXP & Mastery',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
      body: asyncData.when(
        data: (data) {
          final profile = data.profile;
          final achievements = data.achievements;
          final quests = data.quests;
          final balance = data.balance;
          final recentTxs = data.recentTxs;

          return CustomScrollView(
            slivers: [
              // 1. Hero Level & XP Progress Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildHeroLevelCard(profile, isDark),
                ),
              ),

              // 2. Segmented Navigation Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.flash_on_rounded, size: 16),
                        label: Text('Daily Goals'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.military_tech_rounded, size: 16),
                        label: Text('Badges'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.radar_rounded, size: 16),
                        label: Text('Life Radar'),
                      ),
                      ButtonSegment(
                        value: 3,
                        icon: Icon(Icons.history_rounded, size: 16),
                        label: Text('XP Log'),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (val) => setState(() => _selectedTab = val.first),
                  ),
                ),
              ),

              // 3. Tab Content
              if (_selectedTab == 0)
                _buildQuestsTab(quests, isDark)
              else if (_selectedTab == 1)
                _buildBadgesTab(achievements, isDark)
              else if (_selectedTab == 2)
                _buildLifeRadarTab(balance, isDark)
              else
                _buildXpLogTab(recentTxs, isDark),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonPalette.amber),
        ),
        error: (err, _) => Center(
          child: Text('Could not load LifeXP: $err'),
        ),
      ),
    );
  }

  Widget _buildHeroLevelCard(LifeXpProfile profile, bool isDark) {
    final progress = profile.progressToNextLevel;
    final percent = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [Colors.amber.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? NeonPalette.amber.withValues(alpha: 0.4) : Colors.amber.shade300,
          width: 1.5,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: NeonPalette.amber.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: NeonPalette.amber.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: NeonPalette.amber, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      profile.rankBadgeIcon,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${profile.level}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        profile.rankTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: NeonPalette.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: NeonPalette.mint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: NeonPalette.mint.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 14, color: NeonPalette.mint),
                    const SizedBox(width: 4),
                    Text(
                      '+${profile.todayXp} Today',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: NeonPalette.mint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // XP Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                '${profile.xpIntoCurrentLevel} / ${profile.xpRequiredForCurrentLevel} XP ($percent%)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(NeonPalette.amber),
            ),
          ),
          const SizedBox(height: 14),
          // Total XP & Milestone Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Score: ${profile.totalXp} XP',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              Text(
                '${profile.nextLevelTargetXp - profile.totalXp} XP to Level ${profile.level + 1} ✨',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: NeonPalette.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestsTab(List<DailyQuest> quests, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DAILY BOUNTIES & QUESTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: NeonPalette.cyan,
                  ),
                ),
                Text(
                  'Auto-synced from your actions ✨',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          for (final q in quests)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: q.isCompleted
                      ? NeonPalette.mint.withValues(alpha: 0.5)
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (q.isCompleted ? NeonPalette.mint : NeonPalette.cyan)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(q.icon, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                q.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  decoration: q.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: NeonPalette.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${q.xpReward} XP',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: NeonPalette.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          q.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: q.progressRatio,
                                  minHeight: 5,
                                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    q.isCompleted ? NeonPalette.mint : NeonPalette.cyan,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${q.currentCount} / ${q.targetCount}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: q.isCompleted ? NeonPalette.mint : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildBadgesTab(List<Achievement> achievements, bool isDark) {
    final filtered = achievements.where((a) {
      if (_badgeFilter == 'unlocked') return a.isUnlocked;
      if (_badgeFilter == 'locked') return !a.isUnlocked;
      return true;
    }).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Filter Chips
          Row(
            children: [
              _buildFilterChip('all', 'All (${achievements.length})', isDark),
              const SizedBox(width: 8),
              _buildFilterChip(
                'unlocked',
                'Unlocked (${achievements.where((a) => a.isUnlocked).length})',
                isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'locked',
                'In Progress (${achievements.where((a) => !a.isUnlocked).length})',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final a in filtered)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: a.isUnlocked
                      ? NeonPalette.amber.withValues(alpha: 0.6)
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: a.isUnlocked
                          ? NeonPalette.amber.withValues(alpha: 0.15)
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: a.isUnlocked ? NeonPalette.amber : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(a.icon, style: TextStyle(fontSize: 22, color: a.isUnlocked ? null : Colors.grey)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: a.isUnlocked ? null : (isDark ? Colors.white60 : Colors.black54),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a.tier.label,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          a.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: a.progressRatio,
                                  minHeight: 5,
                                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    a.isUnlocked ? NeonPalette.amber : NeonPalette.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${a.currentValue} / ${a.targetValue}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _badgeFilter == key;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
      ),
      selected: isSelected,
      selectedColor: NeonPalette.amber,
      showCheckmark: false,
      onSelected: (v) {
        if (v) setState(() => _badgeFilter = key);
      },
    );
  }

  Widget _buildLifeRadarTab(LifeBalance balance, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Life Balance Equilibrium',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Automated holistic score across 5 personal domains.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 16),
                _buildEquilibriumRow('⚡ Productivity (Tasks & Focus)', balance.productivity, NeonPalette.cyan),
                _buildEquilibriumRow('🌿 Discipline & Consistency (Habits)', balance.discipline, NeonPalette.mint),
                _buildEquilibriumRow('💰 Wealth & Financial Health (Ledger)', balance.wealth, NeonPalette.violet),
                _buildEquilibriumRow('🧘 Mindfulness (Journal & Mood)', balance.mind, NeonPalette.amber),
                _buildEquilibriumRow('🎯 Strategic Growth (Goals & Notes)', balance.growth, NeonPalette.blue),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEquilibriumRow(String label, double score, Color color) {
    final ratio = (score / 100.0).clamp(0.0, 1.0);
    final percent = score.toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpLogTab(List<XpTransaction> recentTxs, bool isDark) {
    if (recentTxs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.bolt, size: 40, color: NeonPalette.amber),
                const SizedBox(height: 12),
                const Text('No XP transactions yet', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Complete tasks, habits, and focus sessions to automatically earn XP!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final tx = recentTxs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NeonPalette.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt, size: 16, color: NeonPalette.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.reason, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        Text(
                          'Domain: ${tx.domain.toUpperCase()}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${tx.amount} XP',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: NeonPalette.mint),
                  ),
                ],
              ),
            );
          },
          childCount: recentTxs.length,
        ),
      ),
    );
  }
}
