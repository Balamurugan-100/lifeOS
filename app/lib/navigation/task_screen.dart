import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../app.dart';
import '../home/home_controller.dart';

/// Live task list for the Tasks screen (T041).
final taskListProvider = FutureProvider<List<Task>>((ref) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.all();
});

/// The Tasks domain screen (T040): create, edit, complete, delete, manual
/// ordering, optional due date — the full basics-only lifecycle (FR-010).
class TaskScreen extends ConsumerWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        key: const Key('addTaskFab'),
        tooltip: 'Add task',
        onPressed: () => _showTaskDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load tasks: $error')),
        data: (tasks) => _TaskList(tasks: tasks, today: todayLocal()),
      ),
    );
  }

  Future<void> _showTaskDialog(
    BuildContext context,
    WidgetRef ref, {
    Task? existing,
  }) async {
    final result = await showDialog<(String, DateTime?)>(
      context: context,
      builder: (_) => _TaskDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    final repo = await ref.read(taskRepositoryProvider.future);
    if (existing == null) {
      await repo.add(result.$1, dueDate: result.$2);
    } else {
      await repo.updateTitle(existing.id, result.$1);
      await repo.setDueDate(existing.id, result.$2);
    }
    ref.invalidate(taskListProvider);
    ref.invalidate(summariesProvider);
  }
}

class _TaskList extends ConsumerStatefulWidget {
  const _TaskList({required this.tasks, required this.today});

  final List<Task> tasks;
  final DateTime today;

  @override
  ConsumerState<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<_TaskList> {
  /// Logical order: section headers (`§...`) interleaved with task ids, so a
  /// single reorderable list preserves both section layout and manual order.
  /// Overdue and undated tasks live in distinct sections (T040).
  late List<String> _entries;

  static const String _headerPrefix = '§';

  @override
  void initState() {
    super.initState();
    _entries = _buildEntries();
  }

  @override
  void didUpdateWidget(covariant _TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entries = _buildEntries();
  }

  List<String> _buildEntries() {
    final outstanding =
        widget.tasks.where((task) => !task.isCompleted).toList();
    final completed = widget.tasks.where((task) => task.isCompleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final overdue =
        outstanding.where((task) => task.isOverdue(widget.today)).toList();
    final upcoming = outstanding
        .where((task) => !task.isOverdue(widget.today) && task.dueDate != null)
        .toList();
    final undated = outstanding.where((task) => task.dueDate == null).toList();

    final entries = <String>[];
    void section(String title, List<Task> items) {
      if (items.isEmpty) return;
      entries.add('$_headerPrefix$title');
      entries.addAll(items.map((task) => task.id));
    }

    section('Overdue', overdue);
    section('Upcoming', upcoming);
    section('No due date', undated);
    section('Completed', completed);
    return entries;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = _entries.removeAt(oldIndex);
    _entries.insert(newIndex, moved);
    setState(() {});
    final orderedIds = _entries
        .where((entry) => !entry.startsWith(_headerPrefix))
        .toList(growable: false);
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.reorder(orderedIds);
    ref.invalidate(taskListProvider);
    ref.invalidate(summariesProvider);
  }

  Future<void> _toggle(Task task) async {
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.toggle(task.id);
    ref.invalidate(taskListProvider);
    ref.invalidate(summariesProvider);
  }

  Future<void> _edit(Task task) async {
    final result = await showDialog<(String, DateTime?)>(
      context: context,
      builder: (_) => _TaskDialog(existing: task),
    );
    if (result == null || !mounted) return;
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.updateTitle(task.id, result.$1);
    await repo.setDueDate(task.id, result.$2);
    ref.invalidate(taskListProvider);
    ref.invalidate(summariesProvider);
  }

  Future<void> _delete(Task task, {bool confirm = true}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete task?'),
          content: Text('"${task.title}" will be removed from this device.'),
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
      if (ok != true || !mounted) return;
    }
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.delete(task.id);
    ref.invalidate(taskListProvider);
    ref.invalidate(summariesProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No tasks yet. Tap + to add your first one.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    final byId = {for (final task in widget.tasks) task.id: task};
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _entries.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        if (entry.startsWith(_headerPrefix)) {
          return Padding(
            key: ValueKey(entry),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              entry.substring(1),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          );
        }
        final task = byId[entry]!;
        return ReorderableDelayedDragStartListener(
          key: ValueKey(entry),
          index: index,
          child: _TaskTile(
            task: task,
            today: widget.today,
            onToggle: () => _toggle(task),
            onDeleteConfirmed: () => _delete(task, confirm: false),
            onDeleteRequested: () => _delete(task),
            onEdit: () => _edit(task),
          ),
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.today,
    required this.onToggle,
    required this.onDeleteConfirmed,
    required this.onDeleteRequested,
    required this.onEdit,
  });

  final Task task;
  final DateTime today;
  final VoidCallback onToggle;
  final VoidCallback onDeleteConfirmed;
  final VoidCallback onDeleteRequested;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue(today);
    final subtitle = task.dueDate == null
        ? null
        : overdue
            ? 'Overdue · ${isoDate(task.dueDate!)}'
            : 'Due ${isoDate(task.dueDate!)}';
    return Dismissible(
      key: ValueKey('dismiss-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text('"${task.title}" will be removed.'),
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
        return confirmed ?? false;
      },
      onDismissed: (_) => onDeleteConfirmed(),
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: ListTile(
        key: ValueKey('task-${task.id}'),
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          task.title,
          style: task.isCompleted
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: overdue
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDeleteRequested();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

/// Add/edit dialog: title (required, 1-200 chars) and an optional due date.
class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.existing});

  final Task? existing;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _controller;
  DateTime? _dueDate;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.title ?? '');
    _dueDate = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? todayLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty || title.length > 200) {
      setState(() => _errorText = 'Title must be 1–200 characters.');
      return;
    }
    Navigator.of(context).pop((title, _dueDate));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add task' : 'Edit task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('taskTitleField'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Title',
              errorText: _errorText,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('pickDueDate'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(
                  _dueDate == null ? 'Due date' : isoDate(_dueDate!),
                ),
              ),
              if (_dueDate != null)
                IconButton(
                  key: const Key('clearDueDate'),
                  tooltip: 'Clear due date',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _dueDate = null),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveTask'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}