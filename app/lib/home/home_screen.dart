import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../app.dart';
import '../bootstrap/registry_settings.dart';
import '../navigation/domain_placeholder_screen.dart';
import '../navigation/export_screen.dart';
import '../navigation/habit_screen.dart';
import '../navigation/task_screen.dart';
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
      _ => DomainPlaceholderScreen(domainTitle: displayName),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _refresh() async {
    ref.invalidate(summariesProvider);
    await ref.read(summariesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(summariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeOS'),
        actions: [
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
      body: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
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
}

/// FR-004: when no enabled domain has any data, guide the user into their
/// first task or habit instead of showing an empty list.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTask, required this.onAddHabit});

  final VoidCallback onAddTask;
  final VoidCallback onAddHabit;

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
              'Start with tasks or habits — everything stays on this device.',
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}