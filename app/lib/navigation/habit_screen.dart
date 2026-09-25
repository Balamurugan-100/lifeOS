import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_habits/lifeos_habits.dart';

import '../app.dart';
import '../home/home_controller.dart';

class _HabitDayStatus {
  const _HabitDayStatus({
    required this.date,
    required this.isDone,
    required this.isScheduled,
    required this.isToday,
  });

  final DateTime date;
  final bool isDone;
  final bool isScheduled;
  final bool isToday;
}

class _HabitOverviewItem {
  const _HabitOverviewItem({
    required this.habit,
    required this.doneToday,
    required this.streak,
    required this.bestStreak,
    required this.totalDone,
    required this.recent7Days,
    required this.allDates,
  });

  final Habit habit;
  final bool doneToday;
  final int streak;
  final int bestStreak;
  final int totalDone;
  final List<_HabitDayStatus> recent7Days;
  final Set<DateTime> allDates;
}

class _HabitsOverview {
  const _HabitsOverview(this.items);

  final List<_HabitOverviewItem> items;
}

/// Calculate the longest consecutive streak of completed entries.
int _calcBestStreak(Set<DateTime> entryDates, HabitSchedule schedule) {
  if (entryDates.isEmpty) return 0;
  final sortedDates = entryDates.map(calendarDate).toList()..sort();
  var maxStreak = 0;
  var current = 0;
  DateTime? prev;

  for (final d in sortedDates) {
    if (prev == null) {
      current = 1;
    } else {
      final diff = d.difference(prev).inDays;
      if (diff == 1) {
        current++;
      } else if (diff > 1) {
        current = 1;
      }
    }
    if (current > maxStreak) maxStreak = current;
    prev = d;
  }
  return maxStreak;
}

/// Combined habit list with today-state, 7-day matrix, and streaks.
final habitOverviewProvider = FutureProvider<_HabitsOverview>((ref) async {
  final repo = await ref.watch(habitRepositoryProvider.future);
  final habits = await repo.all();
  final today = todayLocal();
  final items = <_HabitOverviewItem>[];

  for (final habit in habits) {
    final dates = await repo.entryDates(habit.id);
    final dateSet = dates.map(calendarDate).toSet();
    final streak = currentStreak(
      entryDates: dateSet,
      schedule: habit.schedule,
      today: today,
    );
    final best = _calcBestStreak(dateSet, habit.schedule);

    // Build past 7 days: from (today - 6) to today
    final recent7Days = <_HabitDayStatus>[];
    for (var i = 6; i >= 0; i--) {
      final day = calendarDate(today.subtract(Duration(days: i)));
      final isDone = dateSet.contains(day);
      final isSched = habit.schedule.isScheduled(day);
      final isT = isSameDay(day, today);
      recent7Days.add(_HabitDayStatus(
        date: day,
        isDone: isDone,
        isScheduled: isSched,
        isToday: isT,
      ));
    }

    items.add(_HabitOverviewItem(
      habit: habit,
      doneToday: dateSet.contains(calendarDate(today)),
      streak: streak,
      bestStreak: best > streak ? best : streak,
      totalDone: dates.length,
      recent7Days: recent7Days,
      allDates: dateSet,
    ));
  }
  return _HabitsOverview(items);
});

/// The feature-rich Habits domain screen: streak dashboard, 7-day interactive
/// matrix, quick starter templates, custom frequencies, and habit stats.
class HabitScreen extends ConsumerWidget {
  const HabitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(habitOverviewProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits & Streaks'),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addHabitFab'),
        tooltip: 'Add habit',
        onPressed: () => _showDefineDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load habits: $error')),
        data: (overview) {
          if (overview.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_outlined,
                    size: 56,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No habits yet. Tap + to build your first streak.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showDefineDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Habit'),
                  ),
                ],
              ),
            );
          }

          final today = todayLocal();
          final totalHabits = overview.items.length;
          final scheduledToday = overview.items
              .where((item) => item.habit.schedule.isScheduled(today))
              .length;
          final completedToday =
              overview.items.where((item) => item.doneToday).length;
          final longestActiveStreak = overview.items.isEmpty
              ? 0
              : overview.items
                  .map((item) => item.streak)
                  .reduce((a, b) => a > b ? a : b);

          final completionRate = scheduledToday > 0
              ? (completedToday / scheduledToday)
              : (totalHabits > 0 ? completedToday / totalHabits : 0.0);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(habitOverviewProvider);
              ref.invalidate(summariesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                // Top Consistency Dashboard Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Today\'s Consistency',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '$completedToday / $scheduledToday Habits Done',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: completionRate,
                              minHeight: 7,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _statItem(
                                context,
                                'Active Habits',
                                '$totalHabits',
                                Icons.loop_outlined,
                                null,
                              ),
                              _statItem(
                                context,
                                'Top Active Streak',
                                '$longestActiveStreak days',
                                Icons.local_fire_department,
                                Colors.orange.shade800,
                              ),
                              _statItem(
                                context,
                                'Today Score',
                                '${(completionRate * 100).toStringAsFixed(0)}%',
                                Icons.check_circle_outline,
                                Colors.green.shade800,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Habit Cards with 7-Day Interactive Matrix
                ...overview.items.map((item) => _HabitTile(item: item)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color? accentColor,
  ) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _showDefineDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String name, HabitSchedule schedule})>(
      context: context,
      builder: (_) => const _HabitDialog(),
    );
    if (result == null || !context.mounted) return;
    final repo = await ref.read(habitRepositoryProvider.future);
    await repo.define(result.name, schedule: result.schedule);
    ref.invalidate(habitOverviewProvider);
    ref.invalidate(summariesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Habit habit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text('"${habit.name}" and its history will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = await ref.read(habitRepositoryProvider.future);
    await repo.delete(habit.id);
    ref.invalidate(habitOverviewProvider);
    ref.invalidate(summariesProvider);
  }
}

const List<String> _weekdayNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

const List<String> _weekdayInitials = [
  'M', 'T', 'W', 'T', 'F', 'S', 'S',
];

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.item});

  final _HabitOverviewItem item;

  void _showDetailSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HabitDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = item.habit;
    final theme = Theme.of(context);
    final scheduleLabel = habit.schedule.type == ScheduleType.daily
        ? 'Daily'
        : habit.schedule.daysOfWeek!
            .toList()
            .map((day) => _weekdayNames[day - 1])
            .join(' · ');

    return Card(
      key: Key('habit-${habit.id}'),
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Habit name, schedule & streak badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    child: Icon(
                      Icons.local_fire_department,
                      color: item.streak > 0 ? Colors.orange.shade800 : theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scheduleLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.streak > 0
                          ? Colors.orange.shade50
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: item.streak > 0
                            ? Colors.orange.shade300
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: item.streak > 0
                              ? Colors.orange.shade800
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.streak}d streak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: item.streak > 0
                                ? Colors.orange.shade900
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') {
                        const HabitScreen()._delete(context, ref, habit);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete Habit')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive 7-Day Matrix Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: item.recent7Days.map((dayStatus) {
                  final weekday = dayStatus.date.weekday;
                  final initial = _weekdayInitials[weekday - 1];
                  final dayNum = dayStatus.date.day.toString();

                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          initial,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: dayStatus.isToday ? FontWeight.bold : FontWeight.normal,
                            color: dayStatus.isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dayNum,
                          style: TextStyle(
                            fontSize: 9,
                            color: dayStatus.isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Interactive Check circle
                        InkWell(
                          key: dayStatus.isToday ? Key('habit-today-${habit.id}') : null,
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final repo = await ref.read(habitRepositoryProvider.future);
                            if (dayStatus.isDone) {
                              await repo.unrecord(habit.id, dayStatus.date);
                            } else {
                              await repo.record(habit.id, dayStatus.date);
                            }
                            ref.invalidate(habitOverviewProvider);
                            ref.invalidate(summariesProvider);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dayStatus.isDone
                                  ? Colors.green.shade600
                                  : (dayStatus.isToday
                                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                      : Colors.transparent),
                              border: Border.all(
                                color: dayStatus.isDone
                                    ? Colors.green.shade600
                                    : (dayStatus.isToday
                                        ? theme.colorScheme.primary
                                        : (dayStatus.isScheduled
                                            ? theme.colorScheme.outlineVariant
                                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
                                width: dayStatus.isToday ? 1.8 : 1.2,
                              ),
                            ),
                            child: Center(
                              child: dayStatus.isDone
                                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                                  : (dayStatus.isToday
                                      ? Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                      : null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detailed statistics & calendar history bottom sheet.
class _HabitDetailSheet extends StatelessWidget {
  const _HabitDetailSheet({required this.item});

  final _HabitOverviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = todayLocal();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: const Icon(Icons.local_fire_department, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.habit.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      item.habit.schedule.type == ScheduleType.daily ? 'Daily Habit' : 'Weekly Habit',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  context,
                  'Current Streak',
                  '${item.streak} days',
                  Icons.local_fire_department,
                  Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  context,
                  'Best Streak',
                  '${item.bestStreak} days',
                  Icons.emoji_events_outlined,
                  Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  context,
                  'Total Check-ins',
                  '${item.totalDone}',
                  Icons.done_all,
                  Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Past 28 Days Activity',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          // 4-week grid
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(28, (index) {
              final day = calendarDate(today.subtract(Duration(days: 27 - index)));
              final isDone = item.allDates.contains(day);
              final isToday = isSameDay(day, today);

              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: isDone
                      ? Colors.green.shade600
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: isToday
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isToday || isDone ? FontWeight.bold : FontWeight.normal,
                      color: isDone
                          ? Colors.white
                          : (isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Define-habit dialog with daily and weekly frequency selection.
class _HabitDialog extends StatefulWidget {
  const _HabitDialog();

  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  final TextEditingController _controller = TextEditingController();
  ScheduleType _type = ScheduleType.daily;
  final Set<int> _days = {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday};
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 100) {
      setState(() => _errorText = 'Name must be 1–100 characters.');
      return;
    }
    if (_type == ScheduleType.weekly && _days.isEmpty) {
      setState(() => _errorText = 'Pick at least one weekday.');
      return;
    }

    final schedule = _type == ScheduleType.daily
        ? const HabitSchedule.daily()
        : HabitSchedule.weekly(_days);

    Navigator.of(context).pop((name: name, schedule: schedule));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Habit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('habitNameField'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Habit Name *',
                hintText: 'e.g. Morning Workout, Reading',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Frequency',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(value: ScheduleType.daily, label: Text('Daily')),
                ButtonSegment(value: ScheduleType.weekly, label: Text('Weekly')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            if (_type == ScheduleType.weekly) ...[
              const SizedBox(height: 14),
              const Text(
                'Repeat on Days',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      key: Key('weekday-$day'),
                      label: Text(_weekdayNames[day - 1]),
                      selected: _days.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _days.add(day);
                        } else {
                          _days.remove(day);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveHabit'),
          onPressed: _save,
          child: const Text('Create'),
        ),
      ],
    );
  }
}