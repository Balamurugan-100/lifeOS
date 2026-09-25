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
import '../navigation/journal_screen.dart';
import '../navigation/notes_screen.dart';
import '../navigation/task_screen.dart';
import '../theme/theme_controller.dart';
import 'home_controller.dart';
import 'summary_section.dart';

/// The mobile-first home overview (US1): counts + highlighted actionable
/// items from every enabled domain, an empty-state when nothing exists yet,
/// and navigation to each domain (FR-001..FR-004, FR-007).
///
/// Home is a *consumer* of domain summaries — it never depends on a domain
/// package (FR-012).
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

  /// FR-003 / SC-002: the overview is recomputed on every return to home —
  /// no manual refresh, no persisted cache.
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
                color: NeonPalette.cyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.dashboard_customize,
                size: 20,
                color: NeonPalette.cyan,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'LifeOS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                // 1. Executive Greeting Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
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
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: NeonPalette.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: NeonPalette.cyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: NeonPalette.mint,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
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

                // 2. Executive Metric Quick Strip (KPI Cards)
                _buildMetricsRibbon(summaries, isDark),

                // 3. Quick Action Command Hub
                _buildQuickActionLauncher(isDark),

                // Section Divider
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

                // 4. Domain Summary Sections
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

  Widget _buildMetricsRibbon(List<DomainSummary> summaries, bool isDark) {
    int taskCount = 0;
    int habitStreak = 0;
    int focusMins = 0;
    int activeGoals = 0;

    for (final s in summaries) {
      if (s.domainKey == 'tasks') {
        taskCount = s.counts['due today'] ?? s.counts['pending'] ?? 0;
      } else if (s.domainKey == 'habits') {
        habitStreak = s.counts['active streak'] ?? s.counts['completed'] ?? 0;
      } else if (s.domainKey == 'focus') {
        focusMins = s.counts['today focus mins'] ?? 0;
      } else if (s.domainKey == 'goals') {
        activeGoals = s.counts['active goals'] ?? 0;
      }
    }

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          _buildMetricCard(
            label: 'Tasks Focus',
            value: '$taskCount pending',
            icon: Icons.checklist_rounded,
            accentColor: NeonPalette.cyan,
            isDark: isDark,
            onTap: () => _openDomain('tasks', 'Tasks'),
          ),
          _buildMetricCard(
            label: 'Habit Momentum',
            value: '$habitStreak days',
            icon: Icons.local_fire_department_rounded,
            accentColor: NeonPalette.mint,
            isDark: isDark,
            onTap: () => _openDomain('habits', 'Habits'),
          ),
          _buildMetricCard(
            label: 'Deep Work',
            value: '$focusMins mins',
            icon: Icons.timer_outlined,
            accentColor: NeonPalette.rose,
            isDark: isDark,
            onTap: () => _openDomain('focus', 'Focus'),
          ),
          _buildMetricCard(
            label: 'Active OKRs',
            value: '$activeGoals goals',
            icon: Icons.flag_rounded,
            accentColor: NeonPalette.blue,
            isDark: isDark,
            onTap: () => _openDomain('goals', 'Goals'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? NeonPalette.borderDark
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(icon, size: 16, color: accentColor),
                  ],
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionLauncher(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
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
            icon: Icons.play_arrow_rounded,
            color: NeonPalette.rose,
            onTap: () => _openDomain('focus', 'Focus'),
          ),
          _buildQuickActionButton(
            label: 'Note',
            icon: Icons.edit_document,
            color: const Color(0xFF38BDF8),
            onTap: () => _openDomain('notes', 'Notes & Docs'),
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
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