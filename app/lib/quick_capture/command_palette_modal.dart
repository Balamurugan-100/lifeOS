import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';

class CommandPaletteModal extends ConsumerStatefulWidget {
  const CommandPaletteModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommandPaletteModal(),
    );
  }

  @override
  ConsumerState<CommandPaletteModal> createState() => _CommandPaletteModalState();
}

class _CommandPaletteModalState extends ConsumerState<CommandPaletteModal> {
  final _controller = TextEditingController();
  String _selectedMode = 'task'; // 'task', 'expense', 'note', 'block'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _executeCapture() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      if (_selectedMode == 'task') {
        final taskRepo = await ref.read(taskRepositoryProvider.future);
        final parsed = const CommandParser().parseTask(text);
        final priority = switch (parsed.priority) {
          CommandPriority.urgent => TaskPriority.urgent,
          CommandPriority.high => TaskPriority.high,
          CommandPriority.medium => TaskPriority.medium,
          CommandPriority.low => TaskPriority.low,
        };
        final extraTags = parsed.tags.where((t) => t != parsed.category?.toLowerCase()).toList();
        final notes = extraTags.isNotEmpty
            ? extraTags.map((t) => '#$t').join(' ')
            : null;

        await taskRepo.add(
          parsed.cleanTitle,
          priority: priority,
          dueDate: parsed.dueDate,
          category: parsed.category,
          notes: notes,
        );
      } else if (_selectedMode == 'expense') {
        final financeRepo = await ref.read(financeRepositoryProvider.future);
        final accounts = await financeRepo.getAccounts();
        final categories = await financeRepo.getCategories();
        if (accounts.isNotEmpty && categories.isNotEmpty) {
          final parts = text.split(RegExp(r'\s+'));
          double amount = 100.0;
          var note = text;
          for (final part in parts) {
            final cleaned = part.replaceAll('₹', '').replaceAll('\$', '');
            final parsed = double.tryParse(cleaned);
            if (parsed != null) {
              amount = parsed;
              note = text.replaceAll(part, '').trim();
              break;
            }
          }

          // Extract category tag e.g. @food or #groceries
          String? categoryId = accounts.first.id;
          if (categories.isNotEmpty) {
            categoryId = categories.first.id;
            final catMatch = RegExp(r'[@#]([a-zA-Z0-9_\-]+)').firstMatch(note);
            if (catMatch != null) {
              final tag = catMatch.group(1)!.toLowerCase();
              final matchedCat = categories.cast<FinanceCategory?>().firstWhere(
                (c) => c?.name.toLowerCase() == tag,
                orElse: () => null,
              );
              if (matchedCat != null) {
                categoryId = matchedCat.id;
              }
              note = note.replaceAll(catMatch.group(0)!, '').trim();
            }
          }

          await financeRepo.addTransaction(
            accountId: accounts.first.id,
            type: TransactionType.expense,
            categoryId: categoryId,
            amount: amount,
            date: DateTime.now(),
            note: note.isEmpty ? 'Quick Expense' : note,
          );
        }
      } else if (_selectedMode == 'time') {
        // "Ship the release @pomo" resolves to an existing task and starts
        // tracking time against it, creating the task first when nothing
        // matches. Time lives in the Tasks domain, so this only needs the
        // task repository plus the time repository.
        final taskRepo = await ref.read(taskRepositoryProvider.future);
        final timeRepo = await ref.read(timeRepositoryProvider.future);
        final asPomodoro = RegExp(r'[@#](pomo|pomodoro)\b', caseSensitive: false)
            .hasMatch(text);
        final target = await _resolveTask(taskRepo, text) ??
            await taskRepo.add(const CommandParser().parseTask(text).cleanTitle);
        await timeRepo.startSession(
          target.id,
          isPomodoro: asPomodoro,
        );
      }

      ref.invalidate(summariesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Captured to $_selectedMode!'),
            backgroundColor: LifeOSPalette.sage,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing: $e'), backgroundColor: LifeOSPalette.rust),
        );
      }
    }
  }

  /// Finds the task a time-capture line refers to: an exact `@tag` match on
  /// the task's category wins, then a title substring match, then — if the
  /// input is bare — the single most recently created outstanding task.
  Future<Task?> _resolveTask(TaskRepository repo, String text) async {
    final tasks = await repo.all();
    if (tasks.isEmpty) return null;

    final tagMatch = RegExp(r'[@#]([a-zA-Z0-9_\-]+)').firstMatch(text);
    if (tagMatch != null) {
      final tag = tagMatch.group(1)!.toLowerCase();
      for (final task in tasks) {
        if ((task.category ?? '').toLowerCase() == tag) return task;
      }
    }

    final needle = text.toLowerCase();
    for (final task in tasks) {
      if (task.title.toLowerCase().contains(needle)) return task;
    }

    final outstanding =
        tasks.where((t) => !t.isCompleted).toList(growable: false);
    return outstanding.isEmpty ? tasks.first : outstanding.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? LifeOSPalette.teal.withValues(alpha: 0.3) : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: LifeOSPalette.teal.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Command Palette Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: LifeOSPalette.teal, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'QUICK COMMAND PALETTE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: LifeOSPalette.teal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Spotlight ⌘', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mode Selectors
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModeChip('task', 'Task', Icons.checklist_rounded, LifeOSPalette.teal),
                _buildModeChip('time', 'Track Time', Icons.timer_outlined, LifeOSPalette.slate),
                _buildModeChip('expense', 'Expense (₹)', Icons.account_balance_wallet_rounded, LifeOSPalette.clay),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Input Box
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? LifeOSPalette.borderDark : Colors.grey.shade300,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _getHintText(),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    onSubmitted: (_) => _executeCapture(),
                  ),
                ),
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: LifeOSPalette.teal),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, color: LifeOSPalette.teal),
                    onPressed: _executeCapture,
                  ),
              ],
            ),
          ),
          if (_selectedMode == 'task' && _controller.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildLiveTaskPreview(isDark),
          ],
          const SizedBox(height: 12),
          // Smart Tips
          Text(
            _selectedMode == 'task'
                ? '💡 Tip: Type natural commands like "Fix the iOS issue by today @work !urgent"'
                : _selectedMode == 'expense'
                    ? '💡 Tip: Enter amount first e.g. "500 Dinner with team @food"'
                    : _selectedMode == 'block'
                        ? 'Tip: try "Ship release notes @pomo" to start tracking on that task'
                        : '💡 Instant offline capture into your LifeOS database',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTaskPreview(bool isDark) {
    final parsed = const CommandParser().parseTask(_controller.text);
    final hasDueDate = parsed.dueDate != null;
    final hasCategory = parsed.category != null;
    final hasPriority = parsed.priority != CommandPriority.medium;
    final hasExtraTags = parsed.tags.length > 1;

    if (!hasDueDate && !hasCategory && !hasPriority && !hasExtraTags) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasDueDate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LifeOSPalette.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LifeOSPalette.sage.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_rounded, size: 12, color: LifeOSPalette.sage),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${parsed.dueString ?? isoDate(parsed.dueDate!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: LifeOSPalette.sage,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasCategory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LifeOSPalette.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LifeOSPalette.teal.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag_rounded, size: 12, color: LifeOSPalette.teal),
                      const SizedBox(width: 3),
                      Text(
                        '@${parsed.category}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: LifeOSPalette.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasPriority)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (parsed.priority == CommandPriority.urgent
                            ? LifeOSPalette.rust
                            : parsed.priority == CommandPriority.high
                                ? LifeOSPalette.sand
                                : Colors.blueGrey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (parsed.priority == CommandPriority.urgent
                              ? LifeOSPalette.rust
                              : parsed.priority == CommandPriority.high
                                  ? LifeOSPalette.sand
                                  : Colors.blueGrey)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${parsed.priority.badge} ${parsed.priority.label}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: parsed.priority == CommandPriority.urgent
                          ? LifeOSPalette.rust
                          : parsed.priority == CommandPriority.high
                              ? LifeOSPalette.sand
                              : Colors.blueGrey,
                    ),
                  ),
                ),
            ],
          ),
          if (parsed.cleanTitle.isNotEmpty && parsed.cleanTitle != _controller.text.trim()) ...[
            const SizedBox(height: 4),
            Text(
              'Title: "${parsed.cleanTitle}"',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeChip(String key, String label, IconData icon, Color color) {
    final isSelected = _selectedMode == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 14, color: isSelected ? Colors.black : color),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ),
        selected: isSelected,
        selectedColor: color,
        showCheckmark: false,
        onSelected: (val) {
          if (val) setState(() => _selectedMode = key);
        },
      ),
    );
  }

  String _getHintText() {
    return switch (_selectedMode) {
      'task' => 'Fix the iOS issue by today @ios !p1',
      'expense' => '₹250 Lunch with team @food',
      'time' => 'Start the timer on a task... (e.g. Release notes @pomo)',
      _ => 'Type anything...',
    };
  }
}
