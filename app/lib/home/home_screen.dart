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
import '../navigation/goal_screen.dart';
import '../navigation/habit_screen.dart';
import '../navigation/hub_screen.dart';
import '../navigation/journal_screen.dart';
import '../navigation/notes_screen.dart';
import '../navigation/planner_screen.dart';
import '../navigation/review_screen.dart';
import '../navigation/rituals_screen.dart';
import '../navigation/task_screen.dart';
import '../navigation/wellness_screen.dart';
import '../quick_capture/command_palette_modal.dart';
import '../security/pin_dialog.dart';
import '../security/vault_service.dart';
import '../theme/theme_controller.dart';
import 'highlighted_section.dart';
import 'home_controller.dart';

/// The mobile-first home overview: Clean Bento-grid executive command center
/// with Bottom Navigation Bar, Apple Health-style activity rings, 2-column
/// interactive widgets, inline habit check-offs, and zero bottom list clutter.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  int _currentTabIndex = 0;

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

  Future<void> _openDomain(String key, String displayName) async {
    final vaultService = ref.read(vaultServiceProvider);
    final isLocked = await vaultService.isDomainLocked(key);
    if (isLocked && mounted) {
      final unlocked = await PinDialog.show(context, vaultService, displayName);
      if (!unlocked) return;
    }

    if (!mounted) return;

    final Widget screen = switch (key) {
      'tasks' => const TaskScreen(),
      'habits' => const HabitScreen(),
      'finance' => const FinanceScreen(),
      'journal' => const JournalScreen(),
      'focus' => const FocusScreen(),
      'goals' => const GoalScreen(),
      'notes' => const NotesScreen(),
      'rituals' => const RitualsScreen(),
      'planner' => const PlannerScreen(),
      'wellness' => const WellnessScreen(),
      'review' => const ReviewScreen(),
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
      appBar: _currentTabIndex == 0
          ? AppBar(
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
            )
          : null,
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              key: const Key('commandPaletteButton'),
              onPressed: () => CommandPaletteModal.show(context),
              icon: const Icon(Icons.bolt, color: Colors.black),
              label: const Text(
                'Command',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              backgroundColor: NeonPalette.cyan,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) => setState(() => _currentTabIndex = index),
        backgroundColor: isDark ? const Color(0xFF0B1120) : Colors.white,
        indicatorColor: NeonPalette.cyan.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: NeonPalette.cyan),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded, color: NeonPalette.cyan),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded, color: NeonPalette.mint),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: NeonPalette.violet),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded, color: NeonPalette.amber),
            label: 'Hub',
          ),
        ],
      ),
      body: _buildCurrentTabBody(summariesAsync, isDark),
    );
  }

  Widget _buildCurrentTabBody(AsyncValue<List<DomainSummary>> summariesAsync, bool isDark) {
    if (_currentTabIndex == 1) {
      return const TaskScreen();
    } else if (_currentTabIndex == 2) {
      return const HabitScreen();
    } else if (_currentTabIndex == 3) {
      return const FinanceScreen();
    } else if (_currentTabIndex == 4) {
      return const HubScreen();
    }

    // Tab 0: Clean Bento Executive Overview
    return summariesAsync.when(
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
        final visible = summaries.where((summary) => !summary.isEmpty).toList();
        if (visible.isEmpty) {
          return _EmptyState(
            onAddTask: () => setState(() => _currentTabIndex = 1),
            onAddHabit: () => setState(() => _currentTabIndex = 2),
            onOpenFinance: () => setState(() => _currentTabIndex = 3),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

              // 3. 2-Column Bento Grid Interactive Widgets (Clean, Self-Contained)
              _buildBentoGrid(summaries, isDark),

              // 4. Quick Action Launchers Bar
              _buildQuickActionLauncher(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityRingsHero(List<DomainSummary> summaries, bool isDark) {
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
        habitStreak = s.counts['streaksActive'] ?? s.counts['active streak'] ?? 0;
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
              ? [const Color(0xFF0F172A), NeonPalette.surfaceCard]
              : [Colors.white, Colors.blue.shade50.withValues(alpha: 0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? NeonPalette.cyan.withValues(alpha: 0.3) : Colors.grey.shade300,
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
                          fontSize: 14,
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
                        children: [
                          const Text(
                            'Daily Momentum',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: NeonPalette.mint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$habitStreak d streak 🔥',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: NeonPalette.mint,
                              ),
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
    int tasksOutstanding = 0;
    int tasksOverdue = 0;
    DomainSummary? tasksSummary;
    DomainSummary? habitsSummary;

    for (final s in summaries) {
      if (s.domainKey == 'tasks') {
        tasksSummary = s;
        tasksOutstanding = s.counts['outstanding'] ?? 0;
        tasksOverdue = s.counts['overdue'] ?? 0;
      } else if (s.domainKey == 'habits') {
        habitsSummary = s;
        habitsDone = s.counts['doneToday'] ?? 0;
        habitStreak = s.counts['streaksActive'] ?? s.counts['active streak'] ?? 0;
      } else if (s.domainKey == 'finance') {
        spend = s.counts['thisMonthExpense'] ?? 0;
      } else if (s.domainKey == 'focus') {
        focusMins = s.counts['today focus mins'] ?? 0;
      }
    }

    final hasTaskHighlights = tasksSummary != null && tasksSummary.highlighted.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Bento Row 1: Tasks (Cyan) & Habits (Mint)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bento Widget 1: Tasks
              Expanded(
                child: Container(
                  key: const Key('summary-tasks'),
                  decoration: BoxDecoration(
                    color: isDark ? NeonPalette.surfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? NeonPalette.borderDark : Colors.grey.shade200,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openDomain('tasks', 'Tasks'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tasks',
                                  key: Key('open-tasks'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: NeonPalette.cyan,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: NeonPalette.cyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.checklist_rounded,
                                    size: 14,
                                    color: NeonPalette.cyan,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  '$tasksOutstanding outstanding',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (tasksOverdue > 0)
                                  Text(
                                    '$tasksOverdue overdue',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: NeonPalette.rose,
                                    ),
                                  ),
                              ],
                            ),
                            if (hasTaskHighlights) ...[
                              const SizedBox(height: 8),
                              for (final item in tasksSummary.highlighted.take(2))
                                HighlightedItemTile(
                                  summary: tasksSummary,
                                  item: item,
                                  accentColor: NeonPalette.cyan,
                                  onOpenDomain: () => _openDomain('tasks', 'Tasks'),
                                  onComplete: _refresh,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bento Widget 2: Habits (Mint)
              Expanded(
                child: _buildBentoCard(
                  title: 'HABITS',
                  value: habitsSummary != null && habitsSummary.counts.containsKey('doneToday')
                      ? '${habitsSummary.counts['doneToday']} doneToday'
                      : '$habitsDone done',
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
                              : (isDark ? Colors.white12 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bento Row 2: Finance & Focus
          Row(
            children: [
              // Bento Widget 3: Finance (Violet)
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
                        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(NeonPalette.violet),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bento Widget 4: Focus (Rose)
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
                        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(NeonPalette.rose),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bento Row 3: Mind & Vibe (Amber)
          _buildBentoCard(
            title: 'MIND & VIBE',
            value: 'Daily Vibe',
            subtitle: 'Tap an emoji to log reflection',
            icon: Icons.auto_awesome_rounded,
            accentColor: NeonPalette.amber,
            isDark: isDark,
            onTap: () => _openDomain('journal', 'Journal'),
            extraWidget: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
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
        ],
      ),
    );
  }

  Widget _buildMiniMood(String emoji, int score) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _quickLogMood(score),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
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
          color: isDark ? NeonPalette.borderDark : Colors.grey.shade200,
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: accentColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
    final actions = [
      ('Planner', Icons.calendar_today_rounded, NeonPalette.cyan, () => _openDomain('planner', 'Planner')),
      ('Rituals', Icons.wb_sunny_rounded, NeonPalette.amber, () => _openDomain('rituals', 'Rituals')),
      ('Wellness', Icons.battery_charging_full_rounded, NeonPalette.mint, () => _openDomain('wellness', 'Wellness')),
      ('Review', Icons.rate_review_rounded, NeonPalette.violet, () => _openDomain('review', 'Review')),
      ('Notes', Icons.description_outlined, const Color(0xFF38BDF8), () => _openDomain('notes', 'Notes')),
      ('Vault', Icons.lock_outline_rounded, NeonPalette.rose, () async {
        final vaultService = ref.read(vaultServiceProvider);
        final hasPin = await vaultService.hasPin();
        if (mounted) {
          await PinDialog.show(context, vaultService, 'Vault Settings', isSettingPin: !hasPin);
        }
      }),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK LAUNCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.white38 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (label, icon, color, onTap) in actions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? NeonPalette.borderDark : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: const Key('emptystate'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: NeonPalette.cyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: NeonPalette.cyan.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.dashboard_customize,
                size: 56,
                color: NeonPalette.cyan,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your LifeOS is ready',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add tasks, daily habits, and track finances to illuminate your personal executive dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key('openTasks'),
                  onPressed: onAddTask,
                  style: FilledButton.styleFrom(
                    backgroundColor: NeonPalette.cyan,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.add_task, size: 18),
                  label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                FilledButton.tonalIcon(
                  key: const Key('openHabits'),
                  onPressed: onAddHabit,
                  icon: const Icon(Icons.loop, size: 18),
                  label: const Text('Add Habit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
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
    const strokeWidth = 5.0;

    void drawRing(double radius, double ratio, Color color) {
      final bgPaint = Paint()
        ..color = color.withValues(alpha: isDark ? 0.15 : 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, bgPaint);

      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      final sweepAngle = 2 * math.pi * ratio;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        fgPaint,
      );
    }

    drawRing(size.width / 2 - 4, ring1Ratio.clamp(0.01, 1.0), NeonPalette.cyan);
    drawRing(size.width / 2 - 12, ring2Ratio.clamp(0.01, 1.0), NeonPalette.mint);
    drawRing(size.width / 2 - 20, ring3Ratio.clamp(0.01, 1.0), NeonPalette.rose);
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) =>
      oldDelegate.ring1Ratio != ring1Ratio ||
      oldDelegate.ring2Ratio != ring2Ratio ||
      oldDelegate.ring3Ratio != ring3Ratio ||
      oldDelegate.isDark != isDark;
}