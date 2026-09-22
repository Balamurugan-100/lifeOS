import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_habits/lifeos_habits.dart';

import '../app.dart';
import '../home/home_controller.dart';

class _HabitOverviewItem {
  const _HabitOverviewItem({
    required this.habit,
    required this.doneToday,
    required this.streak,
  });

  final Habit habit;
  final bool doneToday;
  final int streak;
}

class _HabitsOverview {
  const _HabitsOverview(this.items);

  final List<_HabitOverviewItem> items;
}

/// Combined habit list with today-state and streaks, computed per refresh
/// (T054). Streaks derive only from scheduled days (data-model rules).
final habitOverviewProvider = FutureProvider<_HabitsOverview>((ref) async {
  final repo = await ref.watch(habitRepositoryProvider.future);
  final habits = await repo.all();
  final today = todayLocal();
  final items = <_HabitOverviewItem>[];
  for (final habit in habits) {
    final dates = await repo.entryDates(habit.id);
    items.add(_HabitOverviewItem(
      habit: habit,
      doneToday: dates.any((date) => isSameDay(date, today)),
      streak: currentStreak(
        entryDates: dates.toSet(),
        schedule: habit.schedule,
        today: today,
      ),
    ));
  }
  return _HabitsOverview(items);
});

/// The Habits domain screen (T053): define habits with preset schedules,
/// record/un-record per-day completions, and see streaks — fully independent
/// of Tasks (FR-011, US3 independent test).
class HabitScreen extends ConsumerWidget {
  const HabitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(habitOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
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
              child: Text(
                'No habits yet. Tap + to build your first streak.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: overview.items.length,
            itemBuilder: (context, index) =>
                _HabitTile(item: overview.items[index]),
          );
        },
      ),
    );
  }

  Future<void> _showDefineDialog(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _HabitDialog(),
    );
    if (name == null || !context.mounted) return;
    // Comfort dialog returns 'name;daily' or 'name;weekly:1,3,5'
    final parts = name.split(';');
    final repo = await ref.read(habitRepositoryProvider.future);
    final schedule = parts[1] == 'daily'
        ? const HabitSchedule.daily()
        : HabitSchedule.weekly(
            parts[2]
                .split(',')
                .map(int.parse)
                .toSet(),
          );
    await repo.define(parts[0], schedule: schedule);
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

final List<String> _weekdayNames = const [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.item});

  final _HabitOverviewItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = item.habit;
    final scheduleLabel = habit.schedule.type == ScheduleType.daily
        ? 'Daily'
        : habit.schedule.daysOfWeek!
            .toList()
            .map((day) => _weekdayNames[day - 1])
            .join(' · ');
    return ListTile(
      key: Key('habit-${habit.id}'),
      leading: const Icon(Icons.loop),
      title: Text(habit.name),
      subtitle: Text('$scheduleLabel · Streak ${item.streak}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.doneToday ? 'Done' : 'Today'),
          Checkbox(
            key: Key('habit-today-${habit.id}'),
            value: item.doneToday,
            onChanged: (checked) async {
              final repo = await ref.read(habitRepositoryProvider.future);
              final today = todayLocal();
              if (checked == true) {
                await repo.record(habit.id, today);
              } else {
                await repo.unrecord(habit.id, today);
              }
              ref.invalidate(habitOverviewProvider);
              ref.invalidate(summariesProvider);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                HabitScreen()._delete(context, ref, habit);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Define-habit dialog: name + preset frequency selection (daily or weekly
/// with days-of-week chips). Weekly schedules require at least one weekday
/// (data-model validation).
class _HabitDialog extends StatefulWidget {
  const _HabitDialog();

  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  final TextEditingController _controller = TextEditingController();
  ScheduleType _type = ScheduleType.daily;
  final Set<int> _days = {DateTime.monday, DateTime.wednesday, DateTime.friday};
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
    final payload = _type == ScheduleType.daily
        ? '$name;daily'
        : '$name;weekly:${(_days.toList()..sort()).join(',')}';
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add habit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('habitNameField'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _errorText,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 12),
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