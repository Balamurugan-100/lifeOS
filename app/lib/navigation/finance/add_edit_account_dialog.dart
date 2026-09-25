import 'package:flutter/material.dart';
import 'package:lifeos_finance/lifeos_finance.dart';

import 'category_icon_helper.dart';

class AddEditAccountDialog extends StatefulWidget {
  const AddEditAccountDialog({super.key, this.existing});

  final Account? existing;

  @override
  State<AddEditAccountDialog> createState() => _AddEditAccountDialogState();
}

class _AddEditAccountDialogState extends State<AddEditAccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _initialBalanceController;
  late final TextEditingController _currencyController;
  late AccountType _type;
  late String _selectedColor;
  late String _selectedIcon;
  String? _errorText;

  static const List<String> _colorOptions = [
    '#3D5AFE', // Indigo
    '#00BCD4', // Cyan
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#607D8B', // Blue Grey
  ];

  static const List<String> _iconOptions = [
    'account_balance',
    'account_balance_wallet',
    'credit_card',
    'savings',
    'trending_up',
    'payments',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _initialBalanceController = TextEditingController(
      text: widget.existing == null
          ? '0'
          : widget.existing!.initialBalance.toStringAsFixed(0),
    );
    _currencyController =
        TextEditingController(text: widget.existing?.currencySymbol ?? '₹');
    _type = widget.existing?.type ?? AccountType.bank;
    _selectedColor = widget.existing?.colorHex ?? _colorOptions.first;
    _selectedIcon = widget.existing?.iconName ?? _iconOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Account name is required');
      return;
    }

    final balance = double.tryParse(_initialBalanceController.text.trim());
    if (balance == null) {
      setState(() => _errorText = 'Please enter a valid initial balance');
      return;
    }

    final currency = _currencyController.text.trim().isEmpty
        ? '₹'
        : _currencyController.text.trim();

    Navigator.of(context).pop((
      name: name,
      type: _type,
      currency: currency,
      initialBalance: balance,
      colorHex: _selectedColor,
      iconName: _selectedIcon,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Account' : 'Add Account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('accountNameField'),
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. HDFC Bank, Main Wallet',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              key: const Key('accountTypeDropdown'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Account Type'),
              items: AccountType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                    switch (type) {
                      AccountType.bank => 'Bank Account',
                      AccountType.cash => 'Cash / Wallet',
                      AccountType.credit => 'Credit Card',
                      AccountType.savings => 'Savings',
                      AccountType.investment => 'Investment',
                    },
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _type = val);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: const Key('accountCurrencyField'),
                    controller: _currencyController,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      hintText: '₹, \$, €',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: TextField(
                    key: const Key('accountInitialBalanceField'),
                    controller: _initialBalanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isEditing ? 'Initial Balance' : 'Starting Balance',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colorOptions.map((hex) {
                final color = CategoryIconHelper.getColor(hex);
                final isSelected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _iconOptions.map((iconName) {
                final icon = CategoryIconHelper.getIcon(iconName);
                final isSelected = _selectedIcon == iconName;
                return ChoiceChip(
                  label: Icon(icon, size: 18),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedIcon = iconName);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveAccountBtn'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
