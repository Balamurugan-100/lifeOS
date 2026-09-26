import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../app.dart';
import '../navigation/export_screen.dart';
import '../navigation/finance_screen.dart';
import '../navigation/habit_screen.dart';
import '../navigation/notifications_screen.dart';
import '../navigation/task_screen.dart';
import '../navigation/time_screen.dart';
import '../quick_capture/command_palette_modal.dart';
import '../theme/theme_controller.dart';
import 'home_controller.dart';
import 'summary_section.dart';

/// The mobile-first home overview for the three surviving domains — Tasks
/// (with time tracking), Habits and Finance.
///
/// The navigation is deliberately small: five destinations, one per core
/// domain plus a Today overview and a More shelf for the utilities. Home is a
/// consumer of [DomainSummary] only (FR-012): it never talks to a domain
/// repository directly, so enabling a module or reshaping a domain cannot
/// break this screen.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  int _currentTabIndex = 0;

  static const int _todayTab = 0;
  static const int _tasksTab = 1;
  static const int _timeTab = 2;
  static const int _habitsTab = 3;
  static const int _financeTab = 4;
  static const int _moreTab = 5;

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

  /// Recomputed on every return to home so summaries never go stale after a
  /// domain screen mutates data.
  @override
  void didPopNext() {
    ref.invalidate(summariesProvider);
  }

  Future<void> _refresh() async {
    ref.invalidate(summariesProvider);
    await ref.read(summariesProvider.future);
  }

  /// Opens one of the three core domains. Used by the summary cards and the
  /// empty state, both of which switch tabs rather than pushing a route, so
  /// the user never loses their place in the bottom bar.
  void _selectTab(int index) {
    setState(() => _currentTabIndex = index);
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
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
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(summariesProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final onToday = _currentTabIndex == _todayTab;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: onToday ? 16 : null,
        title: Row(
          children: [
            if (onToday) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: LifeOSPalette.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.dashboard_customize,
                  size: 18,
                  color: LifeOSPalette.teal,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              onToday ? 'LifeOS' : _tabTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          if (onToday)
            IconButton(
              key: const Key('openNotifications'),
              tooltip: 'Reminders',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => _push(const NotificationsScreen()),
            ),
          IconButton(
            key: const Key('toggleThemeButton'),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          if (onToday)
            IconButton(
              key: const Key('openExport'),
              tooltip: 'Export data',
              icon: const Icon(Icons.ios_share),
              onPressed: () => _push(const ExportScreen()),
            ),
        ],
      ),
      floatingActionButton: onToday
          ? FloatingActionButton.extended(
              key: const Key('commandPaletteButton'),
              onPressed: () => CommandPaletteModal.show(context),
              icon: const Icon(Icons.bolt),
              label: const Text(
                'Command',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: LifeOSPalette.teal,
              foregroundColor: Colors.black,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: _selectTab,
        backgroundColor:
            isDark ? LifeOSPalette.surfaceDark : Colors.white,
        indicatorColor: LifeOSPalette.teal.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(
            key: Key('nav-today'),
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            key: Key('nav-tasks'),
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            key: Key('nav-time'),
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Time',
          ),
          NavigationDestination(
            key: Key('nav-habits'),
            icon: Icon(Icons.loop_outlined),
            selectedIcon: Icon(Icons.loop_rounded),
            label: 'Habits',
          ),
          NavigationDestination(
            key: Key('nav-finance'),
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Finance',
          ),
          NavigationDestination(
            key: Key('nav-more'),
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
      body: switch (_currentTabIndex) {
        _tasksTab => const TaskScreen(),
        _timeTab => const TimeScreen(),
        _habitsTab => const HabitScreen(),
        _financeTab => const FinanceScreen(),
        _moreTab => _buildMoreTab(isDark),
        _ => _buildTodayTab(summariesAsync, isDark),
      },
    );
  }

  String get _tabTitle => switch (_currentTabIndex) {
        _tasksTab => 'Tasks',
        _timeTab => 'Time',
        _habitsTab => 'Habits',
        _financeTab => 'Finance',
        _moreTab => 'More',
        _ => 'LifeOS',
      };

  // ---------------------------------------------------------------- Today

  Widget _buildTodayTab(
    AsyncValue<List<DomainSummary>> summariesAsync,
    bool isDark,
  ) {
    return summariesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: LifeOSPalette.teal),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load your overview: $error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      ),
      data: (summaries) {
        final visible = summaries.where((s) => !s.isEmpty).toList();
        if (visible.isEmpty) {
          return _EmptyState(
            onAddTask: () => _selectTab(_tasksTab),
            onAddHabit: () => _selectTab(_habitsTab),
            onOpenFinance: () => _selectTab(_financeTab),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _buildGreetingHeader(isDark),
              _buildTimeCard(visible, isDark),
              for (final summary in visible)
                SummarySection(
                  summary: summary,
                  onOpenDomain: () => _openDomainTab(summary.domainKey),
                  onItemComplete: (_) => _refresh(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreetingHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getFormattedDate(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: LifeOSPalette.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: LifeOSPalette.teal.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 12,
                    color: LifeOSPalette.teal),
                const SizedBox(width: 5),
                Text(
                  'On device',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? LifeOSPalette.teal : LifeOSPalette.canvas,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The tracked-time headline. Time tracking lives in the Tasks domain, so
  /// this reads the `trackedMinutes` count the Tasks summary publishes
  /// instead of reaching for a repository.
  Widget _buildTimeCard(List<DomainSummary> summaries, bool isDark) {
    DomainSummary? tasks;
    for (final summary in summaries) {
      if (summary.domainKey == 'tasks') tasks = summary;
    }
    final minutes = tasks?.counts['trackedMinutes'] ?? 0;
    final sessions = tasks?.counts['trackedSessions'] ?? 0;

    return Container(
      key: const Key('today-time-card'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: isDark
            ? LifeOSPalette.surfaceCard
            : LifeOSPalette.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? LifeOSPalette.borderDark.withValues(alpha: 0.7)
              : LifeOSPalette.teal.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: LifeOSPalette.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timer_outlined,
                size: 22, color: LifeOSPalette.teal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tracked today',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  minutes == 0
                      ? 'No time logged yet'
                      : '$minutes min across $sessions ${sessions == 1 ? 'session' : 'sessions'}',
                  key: const Key('today-time-value'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _selectTab(_timeTab),
            child: const Text('Time'),
          ),
        ],
      ),
    );
  }

  void _openDomainTab(String domainKey) {
    final tab = switch (domainKey) {
      'tasks' => _tasksTab,
      'time' => _timeTab,
      'habits' => _habitsTab,
      'finance' => _financeTab,
      _ => _todayTab,
    };
    _selectTab(tab);
  }

  // ----------------------------------------------------------------- More

  Widget _buildMoreTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _MoreTile(
          tileKey: const Key('moreNotifications'),
          icon: Icons.notifications_none_rounded,
          title: 'Reminders',
          subtitle: 'Daily nudges for tasks, time and habits',
          accent: LifeOSPalette.teal,
          onTap: () => _push(const NotificationsScreen()),
        ),
        _MoreTile(
          tileKey: const Key('moreExport'),
          icon: Icons.ios_share,
          title: 'Export data',
          subtitle: 'JSON snapshot or a daily Markdown digest',
          accent: LifeOSPalette.sage,
          onTap: () => _push(const ExportScreen()),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'LifeOS keeps everything on this device — no account, no cloud.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      key: tileKey,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? LifeOSPalette.surfaceCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? LifeOSPalette.borderDark.withValues(alpha: 0.7)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: const Key('emptystate'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LifeOSPalette.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: LifeOSPalette.teal.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.dashboard_customize,
                size: 52,
                color: LifeOSPalette.teal,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your LifeOS is ready',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Start with a task, a daily habit, or an account. '
              'Time tracking rides along with every task.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key('openTasks'),
                  onPressed: onAddTask,
                  style: FilledButton.styleFrom(
                    backgroundColor: LifeOSPalette.teal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  icon: const Icon(Icons.add_task, size: 18),
                  label: const Text('Add Task',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                FilledButton.tonalIcon(
                  key: const Key('openHabits'),
                  onPressed: onAddHabit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  icon: const Icon(Icons.loop, size: 18),
                  label: const Text('Add Habit',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  key: const Key('openFinance'),
                  onPressed: onOpenFinance,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  child: const Text('Add Account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
