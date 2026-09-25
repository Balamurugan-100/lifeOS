import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_goals/lifeos_goals.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';

final goalsListProvider =
    FutureProvider.autoDispose<List<Goal>>((ref) async {
  final repo = await ref.watch(goalRepositoryProvider.future);
  return repo.getAllGoals();
});

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key});

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  GoalCategory? _selectedCategory;

  void _showAddGoalDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => _AddGoalDialog(
        onSaved: () {
          ref.invalidate(goalsListProvider);
          ref.invalidate(summariesProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals & Milestones'),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addGoalFab'),
        onPressed: _showAddGoalDialog,
        backgroundColor: NeonPalette.violet,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          final filtered = goals.where((g) {
            if (_selectedCategory == null) return true;
            return g.category == _selectedCategory;
          }).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildCategoryChips(),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        const Icon(Icons.flag_outlined,
                            size: 48, color: Colors.white38),
                        const SizedBox(height: 12),
                        Text(
                          'No goals in this category yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showAddGoalDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create your first goal'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((g) => _buildGoalCard(theme, g)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Goals'),
            selected: _selectedCategory == null,
            onSelected: (_) => setState(() => _selectedCategory = null),
            selectedColor: NeonPalette.violet.withValues(alpha: 0.25),
            checkmarkColor: NeonPalette.violet,
          ),
          const SizedBox(width: 8),
          for (final cat in GoalCategory.values) ...[
            FilterChip(
              label: Text('${cat.icon} ${cat.label}'),
              selected: _selectedCategory == cat,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              selectedColor: NeonPalette.violet.withValues(alpha: 0.25),
              checkmarkColor: NeonPalette.violet,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalCard(ThemeData theme, Goal goal) {
    final progress = goal.progressRatio;
    final progressColor =
        progress >= 1.0 ? NeonPalette.mint : NeonPalette.violet;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: progress >= 1.0
              ? NeonPalette.mint.withValues(alpha: 0.5)
              : NeonPalette.borderDark,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(goal.category.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (goal.description.isNotEmpty)
                        Text(
                          goal.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${goal.progressPercent}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: NeonPalette.surfaceDark,
                color: progressColor,
              ),
            ),
            if (goal.milestones.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                'Milestones',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              for (final m in goal.milestones)
                InkWell(
                  onTap: () async {
                    final repo = await ref.read(goalRepositoryProvider.future);
                    await repo.toggleMilestone(goal.id, m.id);
                    ref.invalidate(goalsListProvider);
                    ref.invalidate(summariesProvider);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          m.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: m.isCompleted
                              ? NeonPalette.mint
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.title,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: m.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: m.isCompleted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (goal.targetDate != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.event, size: 14, color: Colors.white60),
                  const SizedBox(width: 4),
                  Text(
                    'Target: ${goal.targetDate!.year}-${goal.targetDate!.month.toString().padLeft(2, '0')}-${goal.targetDate!.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddGoalDialog extends ConsumerStatefulWidget {
  const _AddGoalDialog({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends ConsumerState<_AddGoalDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _milestoneController = TextEditingController();
  GoalCategory _category = GoalCategory.personal;
  final List<GoalMilestone> _milestones = [];
  DateTime? _targetDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _milestoneController.dispose();
    super.dispose();
  }

  void _addMilestone() {
    final text = _milestoneController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _milestones.add(
        GoalMilestone(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}',
          title: text,
        ),
      );
      _milestoneController.clear();
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = await ref.read(goalRepositoryProvider.future);
    final id = 'goal_${DateTime.now().millisecondsSinceEpoch}';

    await repo.addGoal(
      id: id,
      title: title,
      description: _descController.text.trim(),
      category: _category,
      targetValue: _milestones.isEmpty ? 100.0 : _milestones.length.toDouble(),
      targetDate: _targetDate,
      milestones: _milestones,
    );

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create New Goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Goal Title *',
                hintText: 'e.g. Read 12 books this year',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description / Purpose',
                hintText: 'Why this goal matters...',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<GoalCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final cat in GoalCategory.values)
                  DropdownMenuItem(
                    value: cat,
                    child: Text('${cat.icon} ${cat.label}'),
                  ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Add Milestones (Step by Step)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _milestoneController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Finish book 1',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: NeonPalette.violet),
                  onPressed: _addMilestone,
                ),
              ],
            ),
            if (_milestones.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (int i = 0; i < _milestones.length; i++)
                Row(
                  children: [
                    Text('${i + 1}. ', style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(_milestones[i].title,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          setState(() => _milestones.removeAt(i)),
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
          key: const Key('submitGoalButton'),
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: NeonPalette.violet),
          child: const Text('Create Goal'),
        ),
      ],
    );
  }
}
