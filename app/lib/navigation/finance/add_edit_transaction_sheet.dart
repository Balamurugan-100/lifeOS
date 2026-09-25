import 'package:flutter/material.dart';
import 'package:lifeos_core/lifeos_core.dart' show isoDate, todayLocal;
import 'package:lifeos_finance/lifeos_finance.dart';

import 'category_icon_helper.dart';

class AddEditTransactionSheet extends StatefulWidget {
  const AddEditTransactionSheet({
    super.key,
    required this.accounts,
    required this.categories,
    this.existing,
    this.preselectedAccountId,
    this.preselectedType,
    this.preselectedCategoryId,
    this.initialAmount,
    this.initialNote,
  });

  final List<Account> accounts;
  final List<FinanceCategory> categories;
  final FinanceTransaction? existing;
  final String? preselectedAccountId;
  final TransactionType? preselectedType;
  final String? preselectedCategoryId;
  final double? initialAmount;
  final String? initialNote;

  @override
  State<AddEditTransactionSheet> createState() =>
      _AddEditTransactionSheetState();
}

class _AddEditTransactionSheetState extends State<AddEditTransactionSheet> {
  late TransactionType _type;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _selectedAccountId;
  String? _selectedToAccountId;
  late String _selectedCategoryId;
  late DateTime _selectedDate;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ??
        widget.preselectedType ??
        TransactionType.expense;

    _amountController = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.amount.toStringAsFixed(
              widget.existing!.amount.truncateToDouble() ==
                      widget.existing!.amount
                  ? 0
                  : 2,
            )
          : (widget.initialAmount != null
              ? widget.initialAmount!.toStringAsFixed(0)
              : ''),
    );

    _noteController = TextEditingController(
      text: widget.existing?.note ?? widget.initialNote ?? '',
    );

    _selectedAccountId = widget.existing?.accountId ??
        widget.preselectedAccountId ??
        (widget.accounts.isNotEmpty ? widget.accounts.first.id : '');

    _selectedToAccountId = widget.existing?.toAccountId ??
        (widget.accounts.length > 1
            ? widget.accounts.firstWhere(
                (a) => a.id != _selectedAccountId,
                orElse: () => widget.accounts.last,
              ).id
            : null);

    final filteredCategories = widget.categories
        .where((c) =>
            _type == TransactionType.transfer ||
            c.type.name == _type.name)
        .toList();

    _selectedCategoryId = widget.existing?.categoryId ??
        widget.preselectedCategoryId ??
        (_type == TransactionType.transfer
            ? 'cat_transfer'
            : (filteredCategories.isNotEmpty
                ? filteredCategories.first.id
                : 'cat_misc_expense'));

    _selectedDate = widget.existing?.date ?? todayLocal();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Please enter a valid positive amount');
      return;
    }

    if (_selectedAccountId.isEmpty) {
      setState(() => _errorText = 'Please select an account');
      return;
    }

    if (_type == TransactionType.transfer) {
      if (_selectedToAccountId == null ||
          _selectedToAccountId == _selectedAccountId) {
        setState(
          () => _errorText = 'Transfer destination must be a different account',
        );
        return;
      }
    }

    Navigator.of(context).pop((
      accountId: _selectedAccountId,
      toAccountId: _type == TransactionType.transfer ? _selectedToAccountId : null,
      type: _type,
      categoryId: _type == TransactionType.transfer
          ? 'cat_transfer'
          : _selectedCategoryId,
      amount: amount,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final currencySymbol = widget.accounts
        .firstWhere(
          (a) => a.id == _selectedAccountId,
          orElse: () => widget.accounts.first,
        )
        .currencySymbol;

    final availableCategories = widget.categories
        .where((c) =>
            _type == TransactionType.transfer ||
            c.type.name == _type.name)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Transaction' : 'New Transaction',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented Type Selector
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_downward, color: Colors.red),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_upward, color: Colors.green),
                ),
                ButtonSegment(
                  value: TransactionType.transfer,
                  label: Text('Transfer'),
                  icon: Icon(Icons.swap_horiz, color: Colors.blue),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _type = newSelection.first;
                  if (_type == TransactionType.transfer) {
                    _selectedCategoryId = 'cat_transfer';
                  } else {
                    final cats = widget.categories
                        .where((c) => c.type.name == _type.name)
                        .toList();
                    if (cats.isNotEmpty &&
                        !cats.any((c) => c.id == _selectedCategoryId)) {
                      _selectedCategoryId = cats.first.id;
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextField(
              key: const Key('transactionAmountField'),
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: widget.existing == null,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _type == TransactionType.expense
                    ? Colors.red.shade700
                    : (_type == TransactionType.income
                        ? Colors.green.shade700
                        : Colors.blue.shade700),
              ),
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                labelText: 'Amount',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Account selection
            if (_type == TransactionType.transfer) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedAccountId,
                      decoration: const InputDecoration(labelText: 'From Account'),
                      items: widget.accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedAccountId = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedToAccountId,
                      decoration: const InputDecoration(labelText: 'To Account'),
                      items: widget.accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedToAccountId = val);
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                key: const Key('transactionAccountDropdown'),
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: widget.accounts.map((a) {
                  return DropdownMenuItem(
                    value: a.id,
                    child: Row(
                      children: [
                        Icon(
                          CategoryIconHelper.getIcon(a.iconName),
                          size: 18,
                          color: CategoryIconHelper.getColor(a.colorHex),
                        ),
                        const SizedBox(width: 8),
                        Text(a.name),
                        const SizedBox(width: 8),
                        Text(
                          '(${a.currencySymbol}${a.currentBalance.toStringAsFixed(0)})',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAccountId = val);
                },
              ),
            ],
            const SizedBox(height: 16),

            // Category Selector (if not transfer)
            if (_type != TransactionType.transfer) ...[
              Text(
                'Category',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: availableCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final cat = availableCategories[idx];
                    final isSelected = _selectedCategoryId == cat.id;
                    final color = CategoryIconHelper.getColor(cat.colorHex);
                    return ChoiceChip(
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.2),
                      avatar: Icon(
                        CategoryIconHelper.getIcon(cat.iconName),
                        size: 18,
                        color: isSelected ? color : null,
                      ),
                      label: Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected ? color : null,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategoryId = cat.id);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Date and Note
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('pickTransactionDateBtn'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(isoDate(_selectedDate)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('transactionNoteField'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note / Payee (Optional)',
                hintText: 'e.g. Starbucks, Dinner with friends',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            FilledButton(
              key: const Key('saveTransactionBtn'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                isEditing ? 'Update Transaction' : 'Save Transaction',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
