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

/// The feature-rich Tasks domain screen: create, edit, complete, delete, manual
/// ordering, priority levels, notes, categories, search, and due date filters.
class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Actions'),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('addTaskFab'),
        tooltip: 'Add task',
        onPressed: () => _showTaskDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load tasks: $error')),
        data: (tasks) {
          final today = todayLocal();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(taskListProvider);
              ref.invalidate(summariesProvider);
            },
            child: Column(
              children: [
                _buildTopStatsBar(context, tasks, today),
                _buildSearchAndFilters(context),
                Expanded(
                  child: _TaskList(
                    tasks: tasks,
                    today: today,
                    filter: _selectedFilter,
                    searchQuery: _searchQuery,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopStatsBar(
    BuildContext context,
    List<Task> tasks,
    DateTime today,
  ) {
    final theme = Theme.of(context);
    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final overdue = tasks.where((t) => t.isOverdue(today)).length;
    final dueToday = tasks
        .where((t) => !t.isCompleted && t.dueDate != null && isSameDay(t.dueDate!, today))
        .length;

    final completionRate = total > 0 ? (completed / total) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Task Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '$completed / $total Done (${(completionRate * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completionRate,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statItem(context, 'Total', '$total', Icons.assignment_outlined, null),
                  _statItem(
                    context,
                    'Due Today',
                    '$dueToday',
                    Icons.today_outlined,
                    Colors.blue.shade700,
                  ),
                  _statItem(
                    context,
                    'Overdue',
                    '$overdue',
                    Icons.warning_amber_rounded,
                    overdue > 0 ? Colors.red.shade700 : null,
                  ),
                  _statItem(
                    context,
                    'Completed',
                    '$completed',
                    Icons.check_circle_outline,
                    Colors.green.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildSearchAndFilters(BuildContext context) {
    final filters = ['All', 'Today', 'Upcoming', 'Urgent', 'Completed'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks or notes...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(f, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedFilter = f);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _showTaskDialog(
    BuildContext context,
    WidgetRef ref, {
    Task? existing,
  }) async {
    final result = await showDialog<({
      String title,
      DateTime? dueDate,
      TaskPriority priority,
      String? notes,
      String? category,
    })>(
      context: context,
      builder: (_) => _TaskDialog(existing: existing),
    );

    if (result == null || !context.mounted) return;
    final repo = await ref.read(taskRepositoryProvider.future);
    if (existing == null) {
      await repo.add(
        result.title,
        dueDate: result.dueDate,
        priority: result.priority,
        notes: result.notes,
        category: result.category,
      );
    } else {
      await repo.updateTask(
        existing.id,
        title: result.title,
        dueDate: result.dueDate,
        clearDueDate: result.dueDate == null,
        priority: result.priority,
        notes: result.notes,
        clearNotes: result.notes == null,
        category: result.category,
        clearCategory: result.category == null,
      );
    }
    ref.invalidate(taskListProvider);
    ref.invalidate(summariesProvider);
  }
}

class _TaskList extends ConsumerStatefulWidget {
  const _TaskList({
    required this.tasks,
    required this.today,
    required this.filter,
    required this.searchQuery,
  });

  final List<Task> tasks;
  final DateTime today;
  final String filter;
  final String searchQuery;

  @override
  ConsumerState<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends ConsumerState<_TaskList> {
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

  List<Task> _filteredTasks() {
    return widget.tasks.where((t) {
      if (widget.searchQuery.isNotEmpty) {
        final q = widget.searchQuery.toLowerCase();
        final titleMatch = t.title.toLowerCase().contains(q);
        final notesMatch = t.notes?.toLowerCase().contains(q) == true;
        final catMatch = t.category?.toLowerCase().contains(q) == true;
        if (!titleMatch && !notesMatch && !catMatch) return false;
      }

      switch (widget.filter) {
        case 'Today':
          return !t.isCompleted &&
              t.dueDate != null &&
              isSameDay(t.dueDate!, widget.today);
        case 'Upcoming':
          return !t.isCompleted &&
              t.dueDate != null &&
              !t.isOverdue(widget.today) &&
              !isSameDay(t.dueDate!, widget.today);
        case 'Urgent':
          return !t.isCompleted &&
              (t.priority == TaskPriority.urgent || t.priority == TaskPriority.high);
        case 'Completed':
          return t.isCompleted;
        case 'All':
        default:
          return true;
      }
    }).toList();
  }

  List<String> _buildEntries() {
    final tasksToDisplay = _filteredTasks();
    final outstanding =
        tasksToDisplay.where((task) => !task.isCompleted).toList();
    final completed = tasksToDisplay.where((task) => task.isCompleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final entries = <String>[];
    void section(String title, List<Task> items) {
      if (items.isEmpty) return;
      entries.add('$_headerPrefix$title');
      entries.addAll(items.map((task) => task.id));
    }

    if (widget.filter == 'Completed') {
      section('Completed (${completed.length})', completed);
      return entries;
    }

    final overdue =
        outstanding.where((task) => task.isOverdue(widget.today)).toList();
    final dueToday = outstanding
        .where((task) => task.dueDate != null && isSameDay(task.dueDate!, widget.today))
        .toList();
    final upcoming = outstanding
        .where((task) =>
            !task.isOverdue(widget.today) &&
            task.dueDate != null &&
            !isSameDay(task.dueDate!, widget.today))
        .toList();
    final undated = outstanding.where((task) => task.dueDate == null).toList();

    section('Overdue', overdue);
    section('Due Today', dueToday);
    section('Upcoming', upcoming);
    section('No due date', undated);
    if (completed.isNotEmpty && widget.filter == 'All') {
      section('Completed', completed);
    }

    return entries;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
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
    final result = await showDialog<({
      String title,
      DateTime? dueDate,
      TaskPriority priority,
      String? notes,
      String? category,
    })>(
      context: context,
      builder: (_) => _TaskDialog(existing: task),
    );
    if (result == null || !mounted) return;
    final repo = await ref.read(taskRepositoryProvider.future);
    await repo.updateTask(
      task.id,
      title: result.title,
      dueDate: result.dueDate,
      clearDueDate: result.dueDate == null,
      priority: result.priority,
      notes: result.notes,
      clearNotes: result.notes == null,
      category: result.category,
      clearCategory: result.category == null,
    );
    ref.invalidate(taskListProvider);
    ref.invalidate(summariesProvider);
  }

  Future<void> _delete(Task task, {bool confirm = true}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rtl_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              widget.searchQuery.isNotEmpty
                  ? 'No tasks matching "${widget.searchQuery}"'
                  : 'No tasks found. Tap + to add one.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }
    final byId = {for (final task in widget.tasks) task.id: task};
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _entries.length,
      onReorderItem: _onReorder,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        if (entry.startsWith(_headerPrefix)) {
          return Padding(
            key: ValueKey(entry),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              entry.substring(1),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
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

  Color _priorityColor(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.urgent => Colors.red.shade600,
      TaskPriority.high => Colors.orange.shade700,
      TaskPriority.medium => Colors.amber.shade700,
      TaskPriority.low => Colors.blueGrey.shade400,
    };
  }

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue(today);
    final isDueToday = task.dueDate != null && isSameDay(task.dueDate!, today);
    final theme = Theme.of(context);
    final priorityColor = _priorityColor(task.priority);

    String? dueText;
    if (task.dueDate != null) {
      if (overdue) {
        dueText = 'Overdue · ${isoDate(task.dueDate!)}';
      } else if (isDueToday) {
        dueText = 'Due Today';
      } else {
        dueText = 'Due ${isoDate(task.dueDate!)}';
      }
    }

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
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        key: ValueKey('task-${task.id}'),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: task.isCompleted
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
                : priorityColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority vertical line indicator
              Container(
                width: 4,
                height: 38,
                margin: const EdgeInsets.only(top: 4, right: 4),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? Colors.grey.shade400
                      : priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Checkbox(
                value: task.isCompleted,
                onChanged: (_) => onToggle(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? theme.colorScheme.outline
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.priority.badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (dueText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: overdue
                                  ? theme.colorScheme.errorContainer
                                  : (isDueToday
                                      ? Colors.blue.shade50
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  overdue
                                      ? Icons.warning_amber_rounded
                                      : (isDueToday ? Icons.today : Icons.event_outlined),
                                  size: 11,
                                  color: overdue
                                      ? theme.colorScheme.error
                                      : (isDueToday ? Colors.blue.shade800 : theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  dueText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: overdue || isDueToday ? FontWeight.bold : FontWeight.normal,
                                    color: overdue
                                        ? theme.colorScheme.error
                                        : (isDueToday ? Colors.blue.shade800 : theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (task.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.category!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDeleteRequested();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rich Add/Edit task dialog with Title, Notes, Priority, Category, and Date Presets.
class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.existing});

  final Task? existing;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  String? _category;
  String? _errorText;

  static const List<String> _categoryOptions = [
    'Work',
    'Personal',
    'Health',
    'Shopping',
    'Finance',
    'Study',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _notesController = TextEditingController(text: widget.existing?.notes ?? '');
    _dueDate = widget.existing?.dueDate;
    _priority = widget.existing?.priority ?? TaskPriority.medium;
    _category = widget.existing?.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
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

  void _setDatePreset(int daysFromToday) {
    final today = todayLocal();
    setState(() => _dueDate = today.add(Duration(days: daysFromToday)));
  }

  void _save() {
    final rawTitle = _titleController.text.trim();
    if (rawTitle.isEmpty || rawTitle.length > 200) {
      setState(() => _errorText = 'Title must be 1–200 characters.');
      return;
    }

    var title = rawTitle;
    var dueDate = _dueDate;
    var priority = _priority;
    var category = _category;
    var notes = _notesController.text.trim();

    if (widget.existing == null) {
      final parsed = const CommandParser().parseTask(rawTitle);
      if (parsed.dueDate != null && _dueDate == null) {
        dueDate = parsed.dueDate;
      }
      if (parsed.category != null && (_category == null || _category!.isEmpty)) {
        category = parsed.category;
      }
      if (parsed.priority != CommandPriority.medium && _priority == TaskPriority.medium) {
        priority = switch (parsed.priority) {
          CommandPriority.urgent => TaskPriority.urgent,
          CommandPriority.high => TaskPriority.high,
          CommandPriority.medium => TaskPriority.medium,
          CommandPriority.low => TaskPriority.low,
        };
      }
      if (parsed.cleanTitle.isNotEmpty) {
        title = parsed.cleanTitle;
      }
      if (parsed.tags.length > 1 && notes.isEmpty) {
        final extraTags = parsed.tags.where((t) => t != parsed.category?.toLowerCase()).toList();
        if (extraTags.isNotEmpty) {
          notes = extraTags.map((t) => '#$t').join(' ');
        }
      }
    }

    Navigator.of(context).pop((
      title: title,
      dueDate: dueDate,
      priority: priority,
      notes: notes.isEmpty ? null : notes,
      category: category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final today = todayLocal();

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add task' : 'Edit task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('taskTitleField'),
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Task Title *',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Sub-details (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            const Text(
              'Priority',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(
                  value: TaskPriority.urgent,
                  label: Text('🔴 P1'),
                  tooltip: 'Urgent',
                ),
                ButtonSegment(
                  value: TaskPriority.high,
                  label: Text('🟠 P2'),
                  tooltip: 'High',
                ),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: Text('🟡 P3'),
                  tooltip: 'Medium',
                ),
                ButtonSegment(
                  value: TaskPriority.low,
                  label: Text('⚪ P4'),
                  tooltip: 'Low',
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 14),
            const Text(
              'Due Date',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Today'),
                  backgroundColor: _dueDate != null && isSameDay(_dueDate!, today)
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  onPressed: () => _setDatePreset(0),
                ),
                ActionChip(
                  label: const Text('Tomorrow'),
                  backgroundColor: _dueDate != null &&
                          isSameDay(_dueDate!, today.add(const Duration(days: 1)))
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  onPressed: () => _setDatePreset(1),
                ),
                ActionChip(
                  label: const Text('+7 Days'),
                  backgroundColor: _dueDate != null &&
                          isSameDay(_dueDate!, today.add(const Duration(days: 7)))
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  onPressed: () => _setDatePreset(7),
                ),
                OutlinedButton.icon(
                  key: const Key('pickDueDate'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    _dueDate == null ? 'Custom Date' : isoDate(_dueDate!),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    key: const Key('clearDueDate'),
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Category',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categoryOptions.map((cat) {
                final isSelected = _category == cat;
                return ChoiceChip(
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _category = selected ? cat : null);
                  },
                );
              }).toList(),
            ),
          ],
        ),
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