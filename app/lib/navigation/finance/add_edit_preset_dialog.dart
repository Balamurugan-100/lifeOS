import 'package:flutter/material.dart';
import 'package:lifeos_finance/lifeos_finance.dart';

import 'finance_preset.dart';

class AddEditPresetDialog extends StatefulWidget {
  const AddEditPresetDialog({
    super.key,
    required this.categories,
    this.existing,
  });

  final List<FinanceCategory> categories;
  final FinancePreset? existing;

  @override
  State<AddEditPresetDialog> createState() => _AddEditPresetDialogState();
}

class _AddEditPresetDialogState extends State<AddEditPresetDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _selectedCategoryKeyword;
  late String _selectedEmoji;

  static const List<String> _emojiOptions = [
    '☕', '🍛', '🍔', '🍕', '🥤', '🍦',
    '⛽', '🚕', '🚌', '🚆', '✈️', '🚲',
    '🛒', '🛍️', '💊', '🏥', '🏋️', '🧘',
    '🎬', '🎮', '📚', '🎁', '💡', '💻',
    '📱', '✂️', '🧹', '🧾', '🐕', '🌿',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _amountController = TextEditingController(
      text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '',
    );
    _selectedEmoji = widget.existing?.emoji ?? '☕';

    final expenseCategories =
        widget.categories.where((c) => c.type == CategoryType.expense).toList();
    _selectedCategoryKeyword = widget.existing?.categoryKeyword ??
        (expenseCategories.isNotEmpty ? expenseCategories.first.name : 'General');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a preset name')),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount > 0')),
      );
      return;
    }

    final preset = FinancePreset(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      categoryKeyword: _selectedCategoryKeyword,
      emoji: _selectedEmoji,
    );

    Navigator.of(context).pop(preset);
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories =
        widget.categories.where((c) => c.type == CategoryType.expense).toList();

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Quick-Log Preset' : 'Edit Preset'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Icon / Emoji',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return InkWell(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'e.g. Morning Coffee, Bus Pass, Whey',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Default Amount (₹)',
                hintText: 'e.g. 50',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: expenseCategories.any((c) => c.name == _selectedCategoryKeyword)
                  ? _selectedCategoryKeyword
                  : (expenseCategories.isNotEmpty ? expenseCategories.first.name : null),
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: expenseCategories.map((c) {
                return DropdownMenuItem<String>(
                  value: c.name,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategoryKeyword = val);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop('DELETE'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save Preset'),
        ),
      ],
    );
  }
}
