import 'package:flutter/material.dart';
import 'package:lifeos_finance/lifeos_finance.dart';

import 'category_icon_helper.dart';

class SetBudgetDialog extends StatefulWidget {
  const SetBudgetDialog({
    super.key,
    required this.categories,
    this.existing,
  });

  final List<FinanceCategory> categories;
  final CategoryBudget? existing;

  @override
  State<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends State<SetBudgetDialog> {
  late String _selectedCategoryId;
  late final TextEditingController _limitController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final expenseCategories = widget.categories
        .where((c) => c.type == CategoryType.expense)
        .toList();
    _selectedCategoryId = widget.existing?.categoryId ??
        (expenseCategories.isNotEmpty ? expenseCategories.first.id : '');
    _limitController = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.monthlyLimit.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _save() {
    final limit = double.tryParse(_limitController.text.trim());
    if (limit == null || limit <= 0) {
      setState(() => _errorText = 'Please enter a valid monthly limit');
      return;
    }
    Navigator.of(context).pop((
      categoryId: _selectedCategoryId,
      monthlyLimit: limit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = widget.categories
        .where((c) => c.type == CategoryType.expense)
        .toList();

    return AlertDialog(
      title: Text(widget.existing == null ? 'Set Monthly Budget' : 'Edit Budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('budgetCategoryDropdown'),
            initialValue: _selectedCategoryId,
            decoration: const InputDecoration(labelText: 'Expense Category'),
            items: expenseCategories.map((c) {
              final color = CategoryIconHelper.getColor(c.colorHex);
              return DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Icon(
                      CategoryIconHelper.getIcon(c.iconName),
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(c.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: widget.existing != null
                ? null
                : (val) {
                    if (val != null) setState(() => _selectedCategoryId = val);
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('budgetLimitField'),
            controller: _limitController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Monthly Spending Limit',
              hintText: 'e.g. 5000',
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveBudgetBtn'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
