import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_gamification/lifeos_gamification.dart';

import '../app.dart';
import '../home/home_controller.dart';
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

  final profile = await repo.getProfile();

  final allTasks = await taskRepo.all();
  final tasksDone = allTasks.where((t) => t.isCompleted).length;

  final allHabits = await habitRepo.all();
  final entries = await habitRepo.allEntries();
  final habitStreak = entries.isNotEmpty ? (entries.length / (allHabits.isEmpty ? 1 : allHabits.length)).ceil() : 0;

  final txs = await financeRepo.getTransactions();

  final journalEntries = await journalRepo.getAllEntries();
  final focusSessions = await focusRepo.getAllSessions();
  final totalFocusMins = focusSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

  final goals = await goalRepo.getAllGoals();
  final goalsDone = goals.where((g) => g.isCompleted).length;

  final notes = await noteRepo.getAllNotes();

  final achievements = await repo.getAchievements(
    tasksCompleted: tasksDone,
    habitStreak: habitStreak,
    focusMins: totalFocusMins,
    journalEntries: journalEntries.length,
    goalsCompleted: goalsDone,
    notesCount: notes.length,
    financeTxCount: txs.length,
  );

  final quests = await repo.getDailyQuests(
    tasksDoneToday: tasksDone > 0 ? 2 : 0,
    habitsDoneToday: entries.isNotEmpty ? 2 : 0,
    focusMinsToday: totalFocusMins > 0 ? 30 : 0,
    moodLoggedToday: journalEntries.isNotEmpty,
  );

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

  final recentTxs = await repo.getRecentTransactions(limit: 10);

  return (
    profile: profile,
    achievements: achievements,
    quests: quests,
    balance: balance,
    recentTxs: recentTxs,
  );
});

class GamificationScreen extends ConsumerStatefulWidget {
  const GamificationScreen({super.key});

  @override
  ConsumerState<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends ConsumerState<GamificationScreen> {
  int _selectedTab = 0; // 0: Mastery & Quests, 1: Life Balance Radar, 2: Badges

  Future<void> _claimQuest(DailyQuest quest) async {
    final repo = await ref.read(gamificationRepositoryProvider.future);
    await repo.claimQuest(quest);
    ref.invalidate(gamificationDataProvider);
    ref.invalidate(summariesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Claimed +${quest.xpReward} XP for "${quest.title}"!'),
          backgroundColor: NeonPalette.mint,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(gamificationDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🎮 LifeXP & Mastery',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
              // 1. Hero Level & Mastery Card
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
                        icon: Icon(Icons.bolt, size: 16),
                        label: Text('Quests & XP'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.radar, size: 16),
                        label: Text('Life Radar'),
                      ),
                      ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.military_tech, size: 16),
                        label: Text('Badges'),
                      ),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (set) {
                      setState(() => _selectedTab = set.first);
                    },
                  ),
                ),
              ),

              // 3. Tab Contents
              if (_selectedTab == 0) ...[
                // Daily Quests Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DAILY BOUNTIES & QUESTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: NeonPalette.amber,
                          ),
                        ),
                        Text(
                          '${quests.where((q) => q.isCompleted).length}/${quests.length} Completed',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildQuestCard(quests[index], isDark),
                      childCount: quests.length,
                    ),
                  ),
                ),

                // Recent XP Stream
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.history,
                            size: 16, color: NeonPalette.cyan),
                        SizedBox(width: 6),
                        Text(
                          'RECENT XP LOG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: NeonPalette.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (recentTxs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Complete tasks, habits, and focus sessions to earn LifeXP!',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildXpLogTile(recentTxs[index], isDark),
                        childCount: recentTxs.length,
                      ),
                    ),
                  ),
              ] else if (_selectedTab == 1) ...[
                // Life Balance Radar Chart & Dimension Sliders
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    child: _buildLifeBalanceView(balance, isDark),
                  ),
                ),
              ] else if (_selectedTab == 2) ...[
                // Achievement Badges Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildBadgeCard(achievements[index], isDark),
                      childCount: achievements.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonPalette.cyan),
        ),
        error: (err, _) => Center(
          child: Text('Error loading gamification: $err'),
        ),
      ),
    );
  }

  Widget _buildHeroLevelCard(LifeXpProfile profile, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B),
                  NeonPalette.surfaceCard,
                ]
              : [
                  Colors.white,
                  Colors.indigo.shade50.withValues(alpha: 0.5),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? NeonPalette.violet.withValues(alpha: 0.35)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: NeonPalette.violet.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                // Rank Avatar Container
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: NeonPalette.violet.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NeonPalette.violet,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      profile.rankBadgeIcon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Level ${profile.level}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: NeonPalette.cyan,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: NeonPalette.violet.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${profile.totalXp} Total XP',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: NeonPalette.violet,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.rankTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // XP Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress to Level ${profile.level + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      '${profile.xpIntoCurrentLevel} / ${profile.xpRequiredForCurrentLevel} XP',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: NeonPalette.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: profile.progressToNextLevel,
                    backgroundColor:
                        isDark ? Colors.white10 : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        NeonPalette.cyan),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard(DailyQuest quest, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: quest.isClaimed
              ? Colors.grey.withValues(alpha: 0.2)
              : (quest.isCompleted
                  ? NeonPalette.mint.withValues(alpha: 0.5)
                  : (isDark ? NeonPalette.borderDark : Colors.grey.shade200)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (quest.isCompleted ? NeonPalette.mint : NeonPalette.amber)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(quest.icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quest.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quest.progressRatio,
                    backgroundColor:
                        isDark ? Colors.white10 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      quest.isCompleted ? NeonPalette.mint : NeonPalette.amber,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (quest.isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Claimed ✓',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            )
          else if (quest.isCompleted)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NeonPalette.mint,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _claimQuest(quest),
              child: Text(
                '+${quest.xpReward} XP',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: NeonPalette.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${quest.xpReward} XP',
                style: const TextStyle(fontSize: 11, color: NeonPalette.amber, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildXpLogTile(XpTransaction tx, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? NeonPalette.borderDark : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.reason,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tx.domain.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: NeonPalette.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${tx.amount} XP',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: NeonPalette.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(Achievement ach, bool isDark) {
    final accent = ach.isUnlocked ? NeonPalette.amber : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ach.isUnlocked
              ? NeonPalette.amber.withValues(alpha: 0.4)
              : (isDark ? NeonPalette.borderDark : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ach.icon, style: const TextStyle(fontSize: 26)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ach.tier.label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ach.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                ach.description,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ach.progressRatio,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ach.isUnlocked ? NeonPalette.mint : NeonPalette.cyan,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ach.currentValue}/${ach.targetValue}',
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey),
                  ),
                  Text(
                    '+${ach.xpReward} XP',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: NeonPalette.cyan),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifeBalanceView(LifeBalance balance, bool isDark) {
    return Column(
      children: [
        // Overall Balance Harmony Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? NeonPalette.surfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: NeonPalette.mint.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Life Balance Equilibrium',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeonPalette.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      balance.harmonyRating,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: NeonPalette.mint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Radar Spider Chart
              SizedBox(
                height: 180,
                child: CustomPaint(
                  size: const Size(180, 180),
                  painter: _RadarChartPainter(
                    balance: balance,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Dimension Breakdown Sliders
        _buildDimensionTile('⚡ Productivity (Tasks & Focus)', balance.productivity, NeonPalette.cyan, isDark),
        _buildDimensionTile('🔥 Discipline (Habits & Streaks)', balance.discipline, NeonPalette.mint, isDark),
        _buildDimensionTile('💰 Wealth (Finance & Savings)', balance.wealth, NeonPalette.violet, isDark),
        _buildDimensionTile('🌅 Mind (Journal & Mood)', balance.mind, NeonPalette.amber, isDark),
        _buildDimensionTile('🎯 Growth (Goals & Knowledge)', balance.growth, const Color(0xFF38BDF8), isDark),
      ],
    );
  }

  Widget _buildDimensionTile(String title, double score, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? NeonPalette.borderDark : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${score.round()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter({required this.balance, required this.isDark});

  final LifeBalance balance;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.3;
    const numPoints = 5;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw 3 concentric polygon guide webs
    for (var r = 0.33; r <= 1.0; r += 0.33) {
      final path = Path();
      for (var i = 0; i < numPoints; i++) {
        final angle = (i * 2 * math.pi / numPoints) - (math.pi / 2);
        final x = center.dx + radius * r * math.cos(angle);
        final y = center.dy + radius * r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw Radar Value Polygon
    final values = [
      balance.productivity / 100.0,
      balance.discipline / 100.0,
      balance.wealth / 100.0,
      balance.mind / 100.0,
      balance.growth / 100.0,
    ];

    final valuePath = Path();
    for (var i = 0; i < numPoints; i++) {
      final angle = (i * 2 * math.pi / numPoints) - (math.pi / 2);
      final r = values[i].clamp(0.1, 1.0);
      final x = center.dx + radius * r * math.cos(angle);
      final y = center.dy + radius * r * math.sin(angle);
      if (i == 0) {
        valuePath.moveTo(x, y);
      } else {
        valuePath.lineTo(x, y);
      }
    }
    valuePath.close();

    final fillPaint = Paint()
      ..color = NeonPalette.mint.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = NeonPalette.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(valuePath, fillPaint);
    canvas.drawPath(valuePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) => true;
}
