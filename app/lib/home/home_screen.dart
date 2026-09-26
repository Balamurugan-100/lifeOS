import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../app.dart';
import '../bootstrap/registry_settings.dart';
import '../navigation/analytics_screen.dart';
import '../navigation/domain_placeholder_screen.dart';
import '../navigation/export_screen.dart';
import '../navigation/finance_screen.dart';
import '../navigation/focus_screen.dart';
import '../navigation/gamification_screen.dart';
import '../navigation/goal_screen.dart';
import '../navigation/habit_screen.dart';
import '../navigation/journal_screen.dart';
import '../navigation/note_editor_screen.dart';
import '../navigation/notes_screen.dart';
import '../navigation/task_screen.dart';
import '../theme/theme_controller.dart';
import 'home_controller.dart';
import 'summary_section.dart';

/// The mobile-first home overview (US1): Bento-grid executive command center
/// with Apple Health-style activity rings, 2-column interactive widgets,
/// inline habit check-offs, live sparklines, and domain control centers.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      homeRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Recomputed on every return to home
  @override
  void didPopNext() {
    ref.invalidate(summariesProvider);
  }

  void _openDomain(String key, String displayName) {
    final Widget screen = switch (key) {
      'tasks' => const TaskScreen(),
      'habits' => const HabitScreen(),
      'finance' => const FinanceScreen(),
      'journal' => const JournalScreen(),
      'focus' => const FocusScreen(),
      'goals' => const GoalScreen(),
      'notes' => const NotesScreen(),
      'gamification' => const GamificationScreen(),
      'analytics' => const AnalyticsScreen(),
      _ => DomainPlaceholderScreen(domainTitle: displayName),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _refresh() async {
    ref.invalidate(summariesProvider);
    await ref.read(summariesProvider.future);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  Future<void> _quickLogMood(int score) async {
    try {
      final repo = await ref.read(journalRepositoryProvider.future);
      final today = isoDate(todayLocal());
      await repo.recordEntry(
        id: 'journal_$today',
        date: today,
        moodScore: score,
        reflection: 'Quick mood logged from Bento executive dashboard.',
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Daily vibe logged!'),
            backgroundColor: NeonPalette.mint,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(summariesProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [NeonPalette.cyan, NeonPalette.blue],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.dashboard_customize,
                size: 20,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'LifeOS',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('openGamification'),
            tooltip: 'LifeXP & Mastery',
            icon: const Icon(Icons.military_tech_rounded, color: NeonPalette.amber),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const GamificationScreen()),
            ),
          ),
          IconButton(
            key: const Key('openAnalytics'),
            tooltip: 'Analytics & Trends',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AnalyticsScreen()),
            ),
          ),
          IconButton(
            key: const Key('toggleThemeButton'),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            icon: Icon(isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            key: const Key('openExport'),
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ExportScreen()),
            ),
          ),
          IconButton(
            key: const Key('openSettings'),
            tooltip: 'Modules',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RegistrySettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.dashboard_customize,
                    size: 40,
                    color: NeonPalette.cyan,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'LifeOS',
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                  ),
                  Text(
                    'Your Personal Operating System',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.checklist, color: NeonPalette.cyan),
              title: const Text('Tasks'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('tasks', 'Tasks');
              },
            ),
            ListTile(
              leading: const Icon(Icons.loop, color: NeonPalette.mint),
              title: const Text('Habits'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('habits', 'Habits');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined,
                  color: NeonPalette.violet),
              title: const Text('Finance'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('finance', 'Finance');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded,
                  color: NeonPalette.amber),
              title: const Text('Journal & Mood'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('journal', 'Journal & Mood');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined, color: NeonPalette.rose),
              title: const Text('Focus & Pomodoro'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('focus', 'Focus & Pomodoro');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: NeonPalette.blue),
              title: const Text('Goals & Milestones'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('goals', 'Goals & Milestones');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined,
                  color: Color(0xFF38BDF8)),
              title: const Text('Notes & Docs'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('notes', 'Notes & Docs');
              },
            ),
            ListTile(
              leading: const Icon(Icons.military_tech_rounded,
                  color: NeonPalette.violet),
              title: const Text('LifeXP & Mastery'),
              onTap: () {
                Navigator.pop(context);
                _openDomain('gamification', 'LifeXP & Mastery');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded,
                  color: NeonPalette.mint),
              title: const Text('Interactive Analytics'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const AnalyticsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Export & Backup'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ExportScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Modules Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegistrySettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: summariesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonPalette.cyan),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load your overview: $error'),
              const SizedBox(height: 8),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
        data: (summaries) {
          final visible =
              summaries.where((summary) => !summary.isEmpty).toList();
          if (visible.isEmpty) {
            return _EmptyState(
              onAddTask: () => _openDomain('tasks', 'Tasks'),
              onAddHabit: () => _openDomain('habits', 'Habits'),
              onOpenFinance: () => _openDomain('finance', 'Finance'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // 1. Executive Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          Text(
                            _getFormattedDate(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: NeonPalette.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: NeonPalette.cyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 13, color: NeonPalette.mint),
                            SizedBox(width: 4),
                            Text(
                              'Live Local',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: NeonPalette.cyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Apple Health-Style Concentric Activity Rings & Day Momentum Hero
                _buildActivityRingsHero(summaries, isDark),

                // 3. 2-Column Bento Grid Widgets
                _buildBentoGrid(summaries, isDark),

                // 4. Quick Action Launchers Bar
                _buildQuickActionLauncher(isDark),

                // 5. Domain Summary Sections
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        'DOMAIN PULSE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white38 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Divider(
                          color: isDark
                              ? NeonPalette.borderDark
                              : Colors.grey.shade300,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                for (final summary in visible)
                  SummarySection(
                    summary: summary,
                    onOpenDomain: () => _openDomain(
                      summary.domainKey,
                      summary.displayName,
                    ),
                    onItemComplete: (_) => _refresh(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityRingsHero(
      List<DomainSummary> summaries, bool isDark) {
    int tasksDone = 0;
    int tasksPending = 0;
    int habitsDone = 0;
    int habitStreak = 0;
    int focusMins = 0;

    for (final s in summaries) {
      if (s.domainKey == 'tasks') {
        tasksDone = s.counts['completedToday'] ?? 0;
        tasksPending = s.counts['outstanding'] ?? s.counts['pending'] ?? 0;
      } else if (s.domainKey == 'habits') {
        habitsDone = s.counts['doneToday'] ?? 0;
        habitStreak =
            s.counts['streaksActive'] ?? s.counts['active streak'] ?? 0;
      } else if (s.domainKey == 'focus') {
        focusMins = s.counts['today focus mins'] ?? 0;
      }
    }

    final totalTasks = tasksDone + tasksPending;
    final taskRatio = totalTasks > 0 ? (tasksDone / totalTasks) : 0.0;
    final habitRatio = habitsDone > 0 ? (habitsDone / 3.0).clamp(0.0, 1.0) : 0.0;
    final focusRatio = focusMins > 0 ? (focusMins / 60.0).clamp(0.0, 1.0) : 0.0;

    final overallScore =
        ((taskRatio * 0.4 + habitRatio * 0.4 + focusRatio * 0.2) * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A),
                  NeonPalette.surfaceCard,
                ]
              : [
                  Colors.white,
                  Colors.blue.shade50.withValues(alpha: 0.4),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? NeonPalette.cyan.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: NeonPalette.cyan.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Concentric Activity Rings Custom Painter
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CustomPaint(
                    painter: _ConcentricRingsPainter(
                      ring1Ratio: taskRatio > 0 ? taskRatio : 0.08,
                      ring2Ratio: habitRatio > 0 ? habitRatio : 0.08,
                      ring3Ratio: focusRatio > 0 ? focusRatio : 0.08,
                      isDark: isDark,
                    ),
                    child: Center(
                      child: Text(
                        '$overallScore%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: NeonPalette.cyan,
                        ),
                      ),
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
                          const Text(
                            'Daily Momentum',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: NeonPalette.mint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 13,
                                  color: NeonPalette.mint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$habitStreak Day Streak',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: NeonPalette.mint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalTasks > 0
                            ? '$tasksDone of $totalTasks tasks done • $habitsDone habits'
                            : 'Personal OS active • Ready for focus',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Mini Ring Legends
                      Row(
                        children: [
                          _buildRingDot(NeonPalette.cyan, 'Tasks'),
                          const SizedBox(width: 10),
                          _buildRingDot(NeonPalette.mint, 'Habits'),
                          const SizedBox(width: 10),
                          _buildRingDot(NeonPalette.rose, 'Focus'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBentoGrid(List<DomainSummary> summaries, bool isDark) {
    int habitStreak = 0;
    int habitsDone = 0;
    int spend = 0;
    int focusMins = 0;

    for (final s in summaries) {
      if (s.domainKey == 'habits') {
        habitsDone = s.counts['doneToday'] ?? 0;
        habitStreak =
            s.counts['streaksActive'] ?? s.counts['active streak'] ?? 0;
      } else if (s.domainKey == 'finance') {
        spend = s.counts['thisMonthExpense'] ?? 0;
      } else if (s.domainKey == 'focus') {
        focusMins = s.counts['today focus mins'] ?? 0;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Bento Row 1: Habits & Finance
          Row(
            children: [
              // Bento Widget 1: Habits (Mint)
              Expanded(
                child: _buildBentoCard(
                  title: 'HABITS',
                  value: '$habitsDone done',
                  subtitle: '$habitStreak day streak',
                  icon: Icons.local_fire_department_rounded,
                  accentColor: NeonPalette.mint,
                  isDark: isDark,
                  onTap: () => _openDomain('habits', 'Habits'),
                  extraWidget: Row(
                    children: List.generate(5, (index) {
                      final active = index < (habitsDone > 0 ? habitsDone : 1);
                      return Container(
                        margin: const EdgeInsets.only(right: 4, top: 6),
                        width: 14,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? NeonPalette.mint
                              : (isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bento Widget 2: Finance (Violet)
              Expanded(
                child: _buildBentoCard(
                  title: 'FINANCE',
                  value: spend > 0 ? '₹$spend' : '₹0',
                  subtitle: 'Month expenses',
                  icon: Icons.account_balance_wallet_outlined,
                  accentColor: NeonPalette.violet,
                  isDark: isDark,
                  onTap: () => _openDomain('finance', 'Finance'),
                  extraWidget: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (spend / 10000.0).clamp(0.05, 1.0),
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            NeonPalette.violet),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bento Row 2: Focus & Mind Vibe
          Row(
            children: [
              // Bento Widget 3: Focus (Rose)
              Expanded(
                child: _buildBentoCard(
                  title: 'DEEP WORK',
                  value: '$focusMins m',
                  subtitle: 'Focus goal: 60m',
                  icon: Icons.timer_outlined,
                  accentColor: NeonPalette.rose,
                  isDark: isDark,
                  onTap: () => _openDomain('focus', 'Focus'),
                  extraWidget: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (focusMins / 60.0).clamp(0.05, 1.0),
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            NeonPalette.rose),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bento Widget 4: Mind & Vibe (Amber)
              Expanded(
                child: _buildBentoCard(
                  title: 'MIND & VIBE',
                  value: 'Daily Vibe',
                  subtitle: 'Tap to log mood',
                  icon: Icons.auto_awesome_rounded,
                  accentColor: NeonPalette.amber,
                  isDark: isDark,
                  onTap: () => _openDomain('journal', 'Journal'),
                  extraWidget: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniMood('😢', 1),
                        _buildMiniMood('😐', 2),
                        _buildMiniMood('🙂', 3),
                        _buildMiniMood('😄', 4),
                        _buildMiniMood('🔥', 5),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMood(String emoji, int score) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _quickLogMood(score),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Text(emoji, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
    Widget? extraWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? NeonPalette.borderDark
              : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: accentColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: accentColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                if (extraWidget != null) extraWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionLauncher(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildQuickActionButton(
            label: 'Task',
            icon: Icons.add_task_rounded,
            color: NeonPalette.cyan,
            onTap: () => _openDomain('tasks', 'Tasks'),
          ),
          _buildQuickActionButton(
            label: 'Habit',
            icon: Icons.loop,
            color: NeonPalette.mint,
            onTap: () => _openDomain('habits', 'Habits'),
          ),
          _buildQuickActionButton(
            label: 'Focus',
            icon: Icons.timer_outlined,
            color: NeonPalette.rose,
            onTap: () => _openDomain('focus', 'Focus'),
          ),
          _buildQuickActionButton(
            label: 'Note',
            icon: Icons.edit_document,
            color: const Color(0xFF38BDF8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NoteEditorScreen(),
                ),
              );
            },
          ),
          _buildQuickActionButton(
            label: 'Journal',
            icon: Icons.edit_note_rounded,
            color: NeonPalette.amber,
            onTap: () => _openDomain('journal', 'Journal'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConcentricRingsPainter extends CustomPainter {
  _ConcentricRingsPainter({
    required this.ring1Ratio,
    required this.ring2Ratio,
    required this.ring3Ratio,
    required this.isDark,
  });

  final double ring1Ratio;
  final double ring2Ratio;
  final double ring3Ratio;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;

    _drawRing(canvas, center, baseRadius - 3, ring1Ratio, NeonPalette.cyan, 4.5);
    _drawRing(canvas, center, baseRadius - 11, ring2Ratio, NeonPalette.mint, 4.5);
    _drawRing(canvas, center, baseRadius - 19, ring3Ratio, NeonPalette.rose, 4.5);
  }

  void _drawRing(
      Canvas canvas, Offset center, double radius, double ratio, Color color, double strokeWidth) {
    final bgPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.15 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * math.pi * ratio.clamp(0.0, 1.0);
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) {
    return oldDelegate.ring1Ratio != ring1Ratio ||
        oldDelegate.ring2Ratio != ring2Ratio ||
        oldDelegate.ring3Ratio != ring3Ratio;
  }
}

/// FR-004: when no enabled domain has any data, guide the user into their
/// first task, habit, or finance account instead of showing an empty list.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAddTask,
    required this.onAddHabit,
    required this.onOpenFinance,
  });

  final VoidCallback onAddTask;
  final VoidCallback onAddHabit;
  final VoidCallback onOpenFinance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const Key('emptystate'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Your LifeOS is ready',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start with tasks, habits, or finances — everything stays on this device.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const Key('openTasks'),
                  onPressed: onAddTask,
                  icon: const Icon(Icons.checklist),
                  label: const Text('Add a task'),
                ),
                FilledButton.icon(
                  key: const Key('openHabits'),
                  onPressed: onAddHabit,
                  icon: const Icon(Icons.loop),
                  label: const Text('Add a habit'),
                ),
                FilledButton.tonalIcon(
                  key: const Key('openFinance'),
                  onPressed: onOpenFinance,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Track finances'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}