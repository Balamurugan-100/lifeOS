import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart' show isoDate, todayLocal;
import 'package:lifeos_finance/lifeos_finance.dart';

import '../../app.dart';
import '../../home/home_controller.dart';
import 'add_edit_account_dialog.dart';
import 'add_edit_transaction_sheet.dart';
import 'category_icon_helper.dart';
import 'reconcile_wizard_screen.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  Future<void> _refresh() async {
    setState(() {});
    ref.invalidate(summariesProvider);
  }

  Future<void> _editAccount(Account account) async {
    final result = await showDialog<(
      {
        String name,
        AccountType type,
        String currency,
        double initialBalance,
        String colorHex,
        String iconName,
      }
    )>(
      context: context,
      builder: (_) => AddEditAccountDialog(existing: account),
    );

    if (result == null || !mounted) return;

    final repo = await ref.read(financeRepositoryProvider.future);
    await repo.updateAccount(
      account.id,
      name: result.name,
      type: result.type,
      currencySymbol: result.currency,
      initialBalance: result.initialBalance,
      colorHex: result.colorHex,
      iconName: result.iconName,
    );
    _refresh();
  }

  Future<void> _deleteAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete "${account.name}"? All related transactions will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = await ref.read(financeRepositoryProvider.future);
    await repo.deleteAccount(account.id);
    _refresh();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openReconcile(Account account) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReconcileWizardScreen(account: account),
      ),
    );
    if (changed == true) _refresh();
  }

  Future<void> _addTransaction(
    Account account, {
    String? preselectedCategoryId,
    double? initialAmount,
    String? initialNote,
  }) async {
    final repo = await ref.read(financeRepositoryProvider.future);
    final accounts = await repo.getAccounts();
    final categories = await repo.getCategories();

    if (!mounted) return;
    final result = await showModalBottomSheet<(
      {
        String accountId,
        String? toAccountId,
        TransactionType type,
        String categoryId,
        double amount,
        DateTime date,
        String? note,
      }
    )>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddEditTransactionSheet(
        accounts: accounts,
        categories: categories,
        preselectedAccountId: account.id,
        preselectedCategoryId: preselectedCategoryId,
        initialAmount: initialAmount,
        initialNote: initialNote,
      ),
    );

    if (result == null || !mounted) return;

    await repo.addTransaction(
      accountId: result.accountId,
      toAccountId: result.toAccountId,
      type: result.type,
      categoryId: result.categoryId,
      amount: result.amount,
      date: result.date,
      note: result.note,
    );
    _refresh();
  }

  Future<void> _quickPreset(
    Account account,
    List<FinanceCategory> categories,
    String label,
    double amount,
    String categoryKeyword,
  ) async {
    final cat = categories.cast<FinanceCategory?>().firstWhere(
          (c) => c?.name.toLowerCase().contains(categoryKeyword.toLowerCase()) == true,
          orElse: () => categories.firstWhere((c) => c.type == CategoryType.expense),
        );

    await _addTransaction(
      account,
      preselectedCategoryId: cat?.id,
      initialAmount: amount,
      initialNote: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<(Account?, List<FinanceTransaction>, List<FinanceCategory>)>(
      future: () async {
        final repo = await ref.read(financeRepositoryProvider.future);
        final account = await repo.getAccountById(widget.accountId);
        final txs = await repo.getTransactions(accountId: widget.accountId);
        final cats = await repo.getCategories();
        return (account, txs, cats);
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final (account, transactions, categories) = snapshot.data!;
        if (account == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Account not found')),
          );
        }

        final catById = {for (final c in categories) c.id: c};
        final color = CategoryIconHelper.getColor(account.colorHex);
        final today = todayLocal();
        final daysSinceReconcile = account.lastReconciledAt == null
            ? null
            : today.difference(account.lastReconciledAt!).inDays;

        return Scaffold(
          appBar: AppBar(
            title: Text(account.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editAccount(account),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteAccount(account),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            key: const Key('addTxForAccountFab'),
            onPressed: () => _addTransaction(account),
            child: const Icon(Icons.add),
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: color.withValues(alpha: 0.25),
                        child: Icon(
                          CategoryIconHelper.getIcon(account.iconName),
                          color: color,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${account.currencySymbol}${account.currentBalance.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        switch (account.type) {
                          AccountType.bank => 'Bank Account',
                          AccountType.cash => 'Cash Wallet',
                          AccountType.credit => 'Credit Card',
                          AccountType.savings => 'Savings Account',
                          AccountType.investment => 'Investment Account',
                        },
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Reconciliation Status badge & action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            daysSinceReconcile != null && daysSinceReconcile < 14
                                ? Icons.verified
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: daysSinceReconcile != null &&
                                    daysSinceReconcile < 14
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            daysSinceReconcile == null
                                ? 'Never reconciled'
                                : (daysSinceReconcile == 0
                                    ? 'Reconciled today'
                                    : 'Reconciled $daysSinceReconcile days ago'),
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.tonalIcon(
                            key: const Key('openReconcileBtn'),
                            onPressed: () => _openReconcile(account),
                            icon: const Icon(Icons.sync_alt, size: 18),
                            label: const Text('Reconcile Balance'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () => _addTransaction(account),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Entry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick presets for this account
                Text(
                  'Quick Log',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Text('☕', style: TextStyle(fontSize: 12)),
                        label: const Text('Chai ₹20'),
                        onPressed: () => _quickPreset(
                          account,
                          categories,
                          'Chai / Tea',
                          20,
                          'Dining',
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Text('🍛', style: TextStyle(fontSize: 12)),
                        label: const Text('Meal ₹150'),
                        onPressed: () => _quickPreset(
                          account,
                          categories,
                          'Meal',
                          150,
                          'Dining',
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Text('⛽', style: TextStyle(fontSize: 12)),
                        label: const Text('Fuel ₹200'),
                        onPressed: () => _quickPreset(
                          account,
                          categories,
                          'Fuel',
                          200,
                          'Transportation',
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Text('🛒', style: TextStyle(fontSize: 12)),
                        label: const Text('Groceries ₹500'),
                        onPressed: () => _quickPreset(
                          account,
                          categories,
                          'Groceries',
                          500,
                          'Groceries',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Transactions section
                Text(
                  'Transactions (${transactions.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No transactions for this account yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...transactions.map((tx) {
                    final cat = catById[tx.categoryId];
                    final catColor = CategoryIconHelper.getColor(cat?.colorHex);
                    final isExpense = tx.type == TransactionType.expense;
                    final isIncome = tx.type == TransactionType.income;

                    return Dismissible(
                      key: ValueKey('detail-tx-${tx.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.shade100,
                        child: Icon(Icons.delete, color: Colors.red.shade900),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Transaction?'),
                            content: const Text('This transaction will be removed.'),
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
                      },
                      onDismissed: (_) async {
                        final repo = await ref.read(financeRepositoryProvider.future);
                        await repo.deleteTransaction(tx.id);
                        _refresh();
                      },
                      child: Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: catColor.withValues(alpha: 0.15),
                            child: Icon(
                              CategoryIconHelper.getIcon(cat?.iconName),
                              color: catColor,
                              size: 20,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Text(
                            '${isExpense ? '-' : (isIncome ? '+' : '')}${account.currencySymbol}${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isExpense
                                  ? Colors.red.shade700
                                  : (isIncome
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
