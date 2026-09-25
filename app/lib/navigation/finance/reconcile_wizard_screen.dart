import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart' show isoDate, todayLocal;
import 'package:lifeos_finance/lifeos_finance.dart';

import '../../app.dart';
import '../../home/home_controller.dart';
import 'category_icon_helper.dart';

/// Helper to sanitize and parse numeric inputs from user typing
double? parseAmountInput(String val) {
  final cleaned = val.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  // If multiple decimal points are present, take up to the first valid float
  final parts = cleaned.split('.');
  if (parts.length > 2) {
    return double.tryParse('${parts[0]}.${parts.sublist(1).join()}');
  }
  return double.tryParse(cleaned);
}

class ReconcileWizardScreen extends ConsumerStatefulWidget {
  const ReconcileWizardScreen({
    super.key,
    required this.account,
  });

  final Account account;

  @override
  ConsumerState<ReconcileWizardScreen> createState() =>
      _ReconcileWizardScreenState();
}

class _ReconcileWizardScreenState extends ConsumerState<ReconcileWizardScreen> {
  late final TextEditingController _actualBalanceController;
  late final TextEditingController _catchUpAmountController;
  late final TextEditingController _catchUpNoteController;

  late double _currentCalculatedBalance;
  double? _initialCalculatedBalance;
  double? _actualStatementBalance;
  bool _isSaving = false;
  bool _isAddingCatchUp = false;

  String? _selectedCategoryId;
  final DateTime _catchUpDate = todayLocal();
  final List<FinanceTransaction> _sessionTransactions = [];

  @override
  void initState() {
    super.initState();
    _currentCalculatedBalance = widget.account.currentBalance;
    _initialCalculatedBalance = widget.account.currentBalance;
    _actualBalanceController = TextEditingController();
    _catchUpAmountController = TextEditingController();
    _catchUpNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _actualBalanceController.dispose();
    _catchUpAmountController.dispose();
    _catchUpNoteController.dispose();
    super.dispose();
  }

  Future<void> _refreshCalculatedBalance() async {
    final repo = await ref.read(financeRepositoryProvider.future);
    final balance = await repo.calculateAccountBalance(widget.account.id);
    if (mounted) {
      setState(() {
        _currentCalculatedBalance = balance;
      });
    }
  }

  void _autoSuggestCategoryFromNote(String note, List<FinanceCategory> categories) {
    if (note.isEmpty) return;
    final lower = note.toLowerCase().trim();

    FinanceCategory? match;
    if (lower.contains('tea') ||
        lower.contains('chai') ||
        lower.contains('coffee') ||
        lower.contains('dinner') ||
        lower.contains('lunch') ||
        lower.contains('breakfast') ||
        lower.contains('food') ||
        lower.contains('snack') ||
        lower.contains('restaurant') ||
        lower.contains('cafe')) {
      match = categories.cast<FinanceCategory?>().firstWhere(
            (c) => c?.name.toLowerCase().contains('dining') == true ||
                c?.name.toLowerCase().contains('food') == true,
            orElse: () => null,
          );
    } else if (lower.contains('grocer') ||
        lower.contains('milk') ||
        lower.contains('veg') ||
        lower.contains('fruit') ||
        lower.contains('supermarket')) {
      match = categories.cast<FinanceCategory?>().firstWhere(
            (c) => c?.name.toLowerCase().contains('grocer') == true,
            orElse: () => null,
          );
    } else if (lower.contains('fuel') ||
        lower.contains('petrol') ||
        lower.contains('diesel') ||
        lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('auto') ||
        lower.contains('cab') ||
        lower.contains('bus') ||
        lower.contains('train') ||
        lower.contains('metro')) {
      match = categories.cast<FinanceCategory?>().firstWhere(
            (c) => c?.name.toLowerCase().contains('transport') == true,
            orElse: () => null,
          );
    } else if (lower.contains('movie') ||
        lower.contains('game') ||
        lower.contains('netflix') ||
        lower.contains('spotify') ||
        lower.contains('show')) {
      match = categories.cast<FinanceCategory?>().firstWhere(
            (c) => c?.name.toLowerCase().contains('entertain') == true,
            orElse: () => null,
          );
    } else if (lower.contains('rent') ||
        lower.contains('wifi') ||
        lower.contains('electric') ||
        lower.contains('water') ||
        lower.contains('recharge') ||
        lower.contains('bill')) {
      match = categories.cast<FinanceCategory?>().firstWhere(
            (c) => c?.name.toLowerCase().contains('util') == true ||
                c?.name.toLowerCase().contains('bill') == true,
            orElse: () => null,
          );
    } else if (lower.contains('shopping') ||
        lower.contains('cloth') ||
        lower.contains('amazon') ||
        lower.contains('flipkart')) {
      match = categories.cast<FinanceCategory?>().firstWhere(
            (c) => c?.name.toLowerCase().contains('shop') == true,
            orElse: () => null,
          );
    }

    if (match != null && mounted) {
      setState(() {
        _selectedCategoryId = match!.id;
      });
    }
  }

  Future<void> _addCatchUpTransaction({
    required List<FinanceCategory> categories,
    required double discrepancy,
  }) async {
    final amount = parseAmountInput(_catchUpAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final note = _catchUpNoteController.text.trim();

    // Determine type: if discrepancy is negative, actual balance is less -> expense missing.
    // If discrepancy is positive, actual balance is more -> income missing.
    final type = discrepancy < 0 ? TransactionType.expense : TransactionType.income;

    // Determine category
    var categoryId = _selectedCategoryId;
    if (categoryId == null || categoryId.isEmpty) {
      final defaultCat = categories.firstWhere(
        (c) => type == TransactionType.expense
            ? c.type == CategoryType.expense
            : c.type == CategoryType.income,
        orElse: () => categories.first,
      );
      categoryId = defaultCat.id;
    }

    setState(() => _isAddingCatchUp = true);

    try {
      final repo = await ref.read(financeRepositoryProvider.future);
      final newTx = await repo.addTransaction(
        accountId: widget.account.id,
        type: type,
        categoryId: categoryId,
        amount: amount,
        date: _catchUpDate,
        note: note.isNotEmpty ? note : null,
      );

      _sessionTransactions.insert(0, newTx);
      _catchUpAmountController.clear();
      _catchUpNoteController.clear();

      await _refreshCalculatedBalance();
      ref.invalidate(summariesProvider);
    } finally {
      if (mounted) setState(() => _isAddingCatchUp = false);
    }
  }

  Future<void> _deleteSessionTransaction(FinanceTransaction tx) async {
    final repo = await ref.read(financeRepositoryProvider.future);
    await repo.deleteTransaction(tx.id);
    setState(() {
      _sessionTransactions.removeWhere((t) => t.id == tx.id);
    });
    await _refreshCalculatedBalance();
    ref.invalidate(summariesProvider);
  }

  Future<void> _completeReconciliation({bool createAdjustment = false}) async {
    if (_actualStatementBalance == null) return;
    setState(() => _isSaving = true);

    try {
      final repo = await ref.read(financeRepositoryProvider.future);
      final discrepancy = _actualStatementBalance! - _currentCalculatedBalance;
      final adjustmentAmount = createAdjustment ? discrepancy : 0.0;

      await repo.completeReconciliation(
        accountId: widget.account.id,
        statementBalance: _actualStatementBalance!,
        adjustmentAmount: adjustmentAmount,
        note: createAdjustment ? 'Balance catch-up adjustment' : null,
      );

      ref.invalidate(summariesProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.account.name} successfully reconciled! 🎉'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = widget.account.currencySymbol;

    final discrepancy = _actualStatementBalance != null
        ? (_actualStatementBalance! - _currentCalculatedBalance)
        : null;

    final isBalanced = discrepancy != null && discrepancy.abs() < 0.01;

    return FutureBuilder<List<FinanceCategory>>(
      future: () async {
        final repo = await ref.read(financeRepositoryProvider.future);
        return await repo.getCategories();
      }(),
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? defaultPredefinedCategories;
        final catById = {for (final c in categories) c.id: c};

        // If no category selected yet, pick a sensible default
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          final defaultExpense = categories.firstWhere(
            (c) => c.name.contains('Food') || c.type == CategoryType.expense,
            orElse: () => categories.first,
          );
          _selectedCategoryId = defaultExpense.id;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reconcile Balance'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Account Info Header
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: CategoryIconHelper.getColor(
                            widget.account.colorHex,
                          ).withValues(alpha: 0.2),
                          child: Icon(
                            CategoryIconHelper.getIcon(widget.account.iconName),
                            color: CategoryIconHelper.getColor(widget.account.colorHex),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.account.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'LifeOS Recorded Balance: $currency${_currentCalculatedBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Step 1: Input Actual Balance
                Text(
                  'Step 1: Check your actual balance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open your bank app or check your cash wallet right now. What is the current balance?',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('actualBalanceInput'),
                  controller: _actualBalanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixText: '$currency ',
                    labelText: 'Current Actual Balance',
                    hintText: '0.00',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  onChanged: (val) {
                    final parsed = parseAmountInput(val);
                    setState(() => _actualStatementBalance = parsed);
                  },
                ),
                const SizedBox(height: 20),

                // Step 2 & Live Status
                if (_actualStatementBalance != null) ...[
                  () {
                    final diff = discrepancy ?? 0.0;
                    final isExpenseGap = diff < 0;

                    // Progress calculation if we started with an initial gap
                    final initialGap = _initialCalculatedBalance != null &&
                            _actualStatementBalance != null
                        ? (_actualStatementBalance! - _initialCalculatedBalance!).abs()
                        : 0.0;
                    final currentGap = diff.abs();
                    final resolvedAmount = (initialGap - currentGap).clamp(0.0, initialGap);
                    final progressRatio = initialGap > 0 ? (resolvedAmount / initialGap) : (isBalanced ? 1.0 : 0.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Live Status Banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isBalanced
                                ? Colors.green.shade50
                                : (isExpenseGap
                                    ? Colors.orange.shade50
                                    : Colors.blue.shade50),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isBalanced
                                  ? Colors.green.shade300
                                  : (isExpenseGap
                                      ? Colors.orange.shade300
                                      : Colors.blue.shade300),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isBalanced
                                        ? Icons.check_circle
                                        : Icons.account_balance_wallet,
                                    color: isBalanced
                                        ? Colors.green.shade700
                                        : (isExpenseGap
                                            ? Colors.orange.shade800
                                            : Colors.blue.shade800),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isBalanced
                                          ? 'Balance Matches Perfectly! 🎉'
                                          : 'Difference to Reconcile: $currency${diff.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isBalanced
                                            ? Colors.green.shade900
                                            : (isExpenseGap
                                                ? Colors.orange.shade900
                                                : Colors.blue.shade900),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isBalanced
                                    ? 'Your LifeOS recorded balance matches your actual statement exactly.'
                                    : (isExpenseGap
                                        ? 'Target: -$currency${diff.abs().toStringAsFixed(2)} · Add forgotten transactions below to bring it to zero.'
                                        : 'Target: +$currency${diff.abs().toStringAsFixed(2)} · Add missing income below to bring it to zero.'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isBalanced
                                      ? Colors.green.shade800
                                      : (isExpenseGap
                                          ? Colors.orange.shade900
                                          : Colors.blue.shade900),
                                ),
                              ),

                              // Progress bar if catching up
                              if (!isBalanced && initialGap > 0) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progressRatio.clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: Colors.white,
                                    valueColor: AlwaysStoppedAnimation(
                                      isExpenseGap ? Colors.orange.shade700 : Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Catch-up progress',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isExpenseGap
                                            ? Colors.orange.shade900
                                            : Colors.blue.shade900,
                                      ),
                                    ),
                                    Text(
                                      '${(progressRatio * 100).toInt()}% resolved',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isExpenseGap
                                            ? Colors.orange.shade900
                                            : Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Step 2: Multi-Transaction Catch-Up Builder
                        if (!isBalanced) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Step 2: Add forgotten items',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (diff.abs() > 0)
                                TextButton.icon(
                                  onPressed: () {
                                    _catchUpAmountController.text =
                                        diff.abs().toStringAsFixed(2);
                                  },
                                  icon: const Icon(Icons.flash_on, size: 16),
                                  label: Text('Fill $currency${diff.abs().toStringAsFixed(0)}'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isExpenseGap
                                ? 'Quickly enter amounts you spent (e.g. 200 on dinner, 40 on tea, 60 on snacks):'
                                : 'Quickly enter income received (e.g. 500 cashback, 1000 freelance):',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Quick Inline Entry Card
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      // Amount Field
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          key: const Key('catchUpAmountInput'),
                                          controller: _catchUpAmountController,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            prefixText: '$currency ',
                                            labelText: 'Amount',
                                            hintText: diff.abs().toStringAsFixed(0),
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Note / What Field
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          key: const Key('catchUpNoteInput'),
                                          controller: _catchUpNoteController,
                                          textInputAction: TextInputAction.done,
                                          decoration: const InputDecoration(
                                            labelText: 'For what? (e.g. dinner, tea)',
                                            hintText: 'Dinner, snacks, fuel...',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          onChanged: (val) =>
                                              _autoSuggestCategoryFromNote(
                                                  val, categories),
                                          onSubmitted: (_) =>
                                              _addCatchUpTransaction(
                                            categories: categories,
                                            discrepancy: diff,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Category chips selector
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final cat in categories
                                            .where((c) => isExpenseGap
                                                ? c.type == CategoryType.expense
                                                : c.type == CategoryType.income)
                                            .take(7))
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6),
                                            child: ChoiceChip(
                                              avatar: Icon(
                                                CategoryIconHelper.getIcon(
                                                    cat.iconName),
                                                size: 14,
                                                color: CategoryIconHelper
                                                    .getColor(cat.colorHex),
                                              ),
                                              label: Text(
                                                cat.name,
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              selected:
                                                  _selectedCategoryId == cat.id,
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setState(() {
                                                    _selectedCategoryId = cat.id;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Add button
                                  FilledButton.icon(
                                    key: const Key('addCatchUpTxBtn'),
                                    onPressed: _isAddingCatchUp
                                        ? null
                                        : () => _addCatchUpTransaction(
                                              categories: categories,
                                              discrepancy: diff,
                                            ),
                                    icon: _isAddingCatchUp
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.add),
                                    label: const Text('Add Transaction'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Session Catch-Up Transactions History
                        if (_sessionTransactions.isNotEmpty) ...[
                          Text(
                            'Added in this session (${_sessionTransactions.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._sessionTransactions.map((tx) {
                            final cat = catById[tx.categoryId];
                            final catColor = CategoryIconHelper.getColor(cat?.colorHex);
                            final isExpense = tx.type == TransactionType.expense;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: catColor.withValues(alpha: 0.2),
                                  child: Icon(
                                    CategoryIconHelper.getIcon(cat?.iconName),
                                    color: catColor,
                                    size: 16,
                                  ),
                                ),
                                title: Text(
                                  tx.note != null && tx.note!.isNotEmpty
                                      ? tx.note!
                                      : (cat?.name ?? 'Transaction'),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${isoDate(tx.date)} · ${cat?.name ?? ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${isExpense ? '-' : '+'}$currency${tx.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isExpense
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      color: Colors.red.shade400,
                                      tooltip: 'Undo/Remove',
                                      onPressed: () =>
                                          _deleteSessionTransaction(tx),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                        ],

                        // Step 3: Complete & Finalize Actions
                        if (isBalanced) ...[
                          FilledButton.icon(
                            key: const Key('confirmReconcileBtn'),
                            onPressed: _isSaving
                                ? null
                                : () => _completeReconciliation(
                                    createAdjustment: false),
                            icon: const Icon(Icons.verified),
                            label: const Text('Complete Reconciliation'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green.shade700,
                            ),
                          ),
                        ] else ...[
                          FilledButton.tonalIcon(
                            key: const Key('adjustBalanceBtn'),
                            onPressed: _isSaving
                                ? null
                                : () => _completeReconciliation(
                                    createAdjustment: true),
                            icon: const Icon(Icons.auto_fix_high),
                            label: Text(
                              'Auto-Adjust Remaining $currency${diff.abs().toStringAsFixed(2)} & Finish',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ],
                    );
                  }(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
