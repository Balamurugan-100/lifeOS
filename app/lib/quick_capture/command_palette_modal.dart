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
  String _selectedMode = 'task'; // 'task', 'expense', 'note', 'block', 'vibe'
  bool _isSaving = false;

  @override
  void dispose() {
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
        final isHigh = text.contains('!high') || text.contains('!urgent');
        final cleanTitle = text.replaceAll('!high', '').replaceAll('!urgent', '').trim();
        await taskRepo.add(
          cleanTitle,
          priority: isHigh ? TaskPriority.high : TaskPriority.medium,
          dueDate: DateTime.now().add(const Duration(days: 1)),
        );
      } else if (_selectedMode == 'expense') {
        final financeRepo = await ref.read(financeRepositoryProvider.future);
        final accounts = await financeRepo.getAccounts();
        final categories = await financeRepo.getCategories();
        if (accounts.isNotEmpty && categories.isNotEmpty) {
          final parts = text.split(RegExp(r'\s+'));
          double amount = 100.0;
          String note = text;
          for (final part in parts) {
            final cleaned = part.replaceAll('₹', '').replaceAll('\$', '');
            final parsed = double.tryParse(cleaned);
            if (parsed != null) {
              amount = parsed;
              note = text.replaceAll(part, '').trim();
              break;
            }
          }
          await financeRepo.addTransaction(
            accountId: accounts.first.id,
            type: TransactionType.expense,
            categoryId: categories.first.id,
            amount: amount,
            date: DateTime.now(),
            note: note.isEmpty ? 'Quick Expense' : note,
          );
        }
      } else if (_selectedMode == 'block') {
        final plannerRepo = await ref.read(plannerRepositoryProvider.future);
        final now = DateTime.now();
        final startMinute = (now.hour * 60) + now.minute;
        await plannerRepo.createBlock(
          title: text,
          date: today,
          startMinute: startMinute,
          durationMinutes: 45,
          category: BlockCategory.focus,
        );
      } else if (_selectedMode == 'note') {
        final noteRepo = await ref.read(notesRepositoryProvider.future);
        await noteRepo.addNote(
          id: newId(),
          title: text.length > 30 ? text.substring(0, 30) : text,
          content: text,
          tags: ['quick-capture'],
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
          const SizedBox(height: 12),
          // Smart Tips
          Text(
            _selectedMode == 'task'
                ? '💡 Tip: Append "!high" to mark urgent'
                : _selectedMode == 'expense'
                    ? '💡 Tip: Enter amount first e.g. "500 Dinner with team"'
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
      'task' => 'Add new task... (e.g. Design sprint docs !high)',
      'expense' => 'Log expense... (e.g. ₹250 Metro card recharge)',
      'block' => 'Schedule block... (e.g. Core Algorithm Deep Work)',
      'note' => 'Jot thought... (e.g. Ideas for next quarter product)',
      _ => 'Type anything...',
    };
  }
}
