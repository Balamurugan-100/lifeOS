import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_planner/lifeos_planner.dart';
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
    final today = isoDate(todayLocal());

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
      } else if (_selectedMode == 'block') {
        final plannerRepo = await ref.read(plannerRepositoryProvider.future);
        final now = DateTime.now();
        final startMinute = (now.hour * 60) + now.minute;
        var blockTitle = text;
        var duration = 45;
        var category = BlockCategory.focus;

        // Parse duration e.g. 30m, 1h, 90m
        final durMatch = RegExp(r'\b(\d+)\s*(m|min|mins|h|hr|hours?)\b', caseSensitive: false).firstMatch(blockTitle);
        if (durMatch != null) {
          final num = int.parse(durMatch.group(1)!);
          final unit = durMatch.group(2)!.toLowerCase();
          duration = unit.startsWith('h') ? num * 60 : num;
          blockTitle = blockTitle.replaceRange(durMatch.start, durMatch.end, ' ').trim();
        }

        // Parse category e.g. @meeting, @health, @routine, @personal, @focus
        final tagMatch = RegExp(r'[@#]([a-zA-Z0-9_\-]+)').firstMatch(blockTitle);
        if (tagMatch != null) {
          final tag = tagMatch.group(1)!.toLowerCase();
          if (tag.contains('meet')) category = BlockCategory.meeting;
          if (tag.contains('health') || tag.contains('gym')) category = BlockCategory.health;
          if (tag.contains('routine')) category = BlockCategory.routine;
          if (tag.contains('personal') || tag.contains('rest')) category = BlockCategory.personal;
          blockTitle = blockTitle.replaceAll(tagMatch.group(0)!, '').trim();
        }

        await plannerRepo.createBlock(
          title: blockTitle.isEmpty ? text : blockTitle,
          date: today,
          startMinute: startMinute,
          durationMinutes: duration,
          category: category,
        );
      } else if (_selectedMode == 'note') {
        final noteRepo = await ref.read(notesRepositoryProvider.future);
        final tags = <String>['quick-capture'];
        final tagMatches = RegExp(r'[@#]([a-zA-Z0-9_\-]+)').allMatches(text);
        for (final m in tagMatches) {
          final t = m.group(1)!.toLowerCase();
          if (!tags.contains(t)) tags.add(t);
        }
        await noteRepo.addNote(
          id: newId(),
          title: text.length > 30 ? text.substring(0, 30) : text,
          content: text,
          tags: tags,
        );
      }

      ref.invalidate(summariesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Captured to $_selectedMode!'),
            backgroundColor: NeonPalette.mint,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing: $e'), backgroundColor: NeonPalette.rose),
        );
      }
    }
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
          color: isDark ? NeonPalette.cyan.withValues(alpha: 0.3) : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: NeonPalette.cyan.withValues(alpha: 0.15),
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
                  Icon(Icons.bolt, color: NeonPalette.cyan, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'QUICK COMMAND PALETTE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: NeonPalette.cyan,
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
                _buildModeChip('task', 'Task', Icons.checklist_rounded, NeonPalette.cyan),
                _buildModeChip('expense', 'Expense (₹)', Icons.account_balance_wallet_rounded, NeonPalette.violet),
                _buildModeChip('block', 'Time Block', Icons.calendar_today_rounded, NeonPalette.blue),
                _buildModeChip('note', 'Quick Note', Icons.description_rounded, const Color(0xFF38BDF8)),
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
                color: isDark ? NeonPalette.borderDark : Colors.grey.shade300,
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: NeonPalette.cyan),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, color: NeonPalette.cyan),
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
                        ? '💡 Tip: Try "Deep work 45m @focus" or "Team Sync 30m @meeting"'
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
                    color: NeonPalette.mint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeonPalette.mint.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_rounded, size: 12, color: NeonPalette.mint),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${parsed.dueString ?? isoDate(parsed.dueDate!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: NeonPalette.mint,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasCategory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NeonPalette.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeonPalette.cyan.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag_rounded, size: 12, color: NeonPalette.cyan),
                      const SizedBox(width: 3),
                      Text(
                        '@${parsed.category}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: NeonPalette.cyan,
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
                            ? NeonPalette.rose
                            : parsed.priority == CommandPriority.high
                                ? NeonPalette.amber
                                : Colors.blueGrey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (parsed.priority == CommandPriority.urgent
                              ? NeonPalette.rose
                              : parsed.priority == CommandPriority.high
                                  ? NeonPalette.amber
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
                          ? NeonPalette.rose
                          : parsed.priority == CommandPriority.high
                              ? NeonPalette.amber
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
      'block' => 'Schedule block... (e.g. Core Engine 45m @focus)',
      'note' => 'Jot thought... (e.g. Architecture plan @v2)',
      _ => 'Type anything...',
    };
  }
}
