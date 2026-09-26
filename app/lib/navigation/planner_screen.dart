import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_planner/lifeos_planner.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';

final selectedPlannerDateProvider = StateProvider<String>((ref) {
  return isoDate(todayLocal());
});

final plannerBlocksProvider = FutureProvider.autoDispose<List<TimeBlock>>((ref) async {
  final repo = await ref.watch(plannerRepositoryProvider.future);
  final date = ref.watch(selectedPlannerDateProvider);
  return repo.getBlocksForDate(date);
});

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  Future<void> _toggleBlock(String id) async {
    final repo = await ref.read(plannerRepositoryProvider.future);
    await repo.toggleBlockCompletion(id);
    ref.invalidate(plannerBlocksProvider);
    ref.invalidate(summariesProvider);
  }

  void _showAddBlockSheet() {
    final titleCtrl = TextEditingController();
    int startHour = 9;
    int startMin = 0;
    int duration = 60;
    BlockCategory category = BlockCategory.focus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schedule Time Block', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Block Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                // Category Picker
                DropdownButtonFormField<BlockCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: BlockCategory.values.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => category = val);
                  },
                ),
                const SizedBox(height: 14),
                // Time & Duration Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(hour: startHour, minute: startMin),
                          );
                          if (time != null) {
                            setSheetState(() {
                              startHour = time.hour;
                              startMin = time.minute;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                          child: Text(
                            TimeOfDay(hour: startHour, minute: startMin).format(ctx),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: duration,
                        decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 25, child: Text('25 mins')),
                          DropdownMenuItem(value: 45, child: Text('45 mins')),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                          DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                          DropdownMenuItem(value: 120, child: Text('2 hours')),
                        ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => duration = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isNotEmpty) {
                        final repo = await ref.read(plannerRepositoryProvider.future);
                        final date = ref.read(selectedPlannerDateProvider);
                        final startMinute = (startHour * 60) + startMin;

                        await repo.createBlock(
                          title: title,
                          date: date,
                          startMinute: startMinute,
                          durationMinutes: duration,
                          category: category,
                        );
                        ref.invalidate(plannerBlocksProvider);
                        ref.invalidate(summariesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Schedule Block'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(plannerBlocksProvider);
    final selectedDate = ref.watch(selectedPlannerDateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⏰ Time Blocking Blueprint', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Schedule Block',
            onPressed: _showAddBlockSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: isDark ? NeonPalette.borderDark : Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        final current = DateTime.parse(selectedDate);
                        final prev = current.subtract(const Duration(days: 1));
                        ref.read(selectedPlannerDateProvider.notifier).state = isoDate(prev);
                      },
                    ),
                    Text(
                      selectedDate == isoDate(todayLocal()) ? 'Today ($selectedDate)' : selectedDate,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        final current = DateTime.parse(selectedDate);
                        final next = current.add(const Duration(days: 1));
                        ref.read(selectedPlannerDateProvider.notifier).state = isoDate(next);
                      },
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text('Today'),
                  onPressed: () {
                    ref.read(selectedPlannerDateProvider.notifier).state = isoDate(todayLocal());
                  },
                ),
              ],
            ),
          ),
          // Timeline Content
          Expanded(
            child: blocksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: NeonPalette.cyan)),
              error: (err, _) => Center(child: Text('Error loading schedule: $err')),
              data: (blocks) {
                if (blocks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 48, color: NeonPalette.cyan),
                        const SizedBox(height: 12),
                        const Text('No blocks scheduled for this day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: _showAddBlockSheet, child: const Text('Add Time Block')),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    return _buildTimelineBlockCard(block, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineBlockCard(TimeBlock block, bool isDark) {
    final color = switch (block.category) {
      BlockCategory.focus => NeonPalette.cyan,
      BlockCategory.routine => NeonPalette.mint,
      BlockCategory.meeting => NeonPalette.violet,
      BlockCategory.health => NeonPalette.rose,
      BlockCategory.breakTime => NeonPalette.amber,
      _ => const Color(0xFF38BDF8),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: block.isCompleted ? NeonPalette.mint.withValues(alpha: 0.4) : color.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: InkWell(
          onTap: () => _toggleBlock(block.id),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: block.isCompleted ? NeonPalette.mint : color.withValues(alpha: 0.15),
              border: Border.all(color: block.isCompleted ? NeonPalette.mint : color),
            ),
            child: Icon(
              block.isCompleted ? Icons.check : Icons.circle_outlined,
              size: 18,
              color: block.isCompleted ? Colors.black : color,
            ),
          ),
        ),
        title: Text(
          block.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            decoration: block.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Text(block.formattedTimeRange, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                block.category.name.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        trailing: Text('${block.durationMinutes}m', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
      ),
    );
  }
}
