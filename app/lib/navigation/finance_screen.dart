import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart' show isoDate, todayLocal;
import 'package:lifeos_finance/lifeos_finance.dart';

import '../app.dart';
import '../home/home_controller.dart';
import 'finance/account_detail_screen.dart';
import 'finance/add_edit_account_dialog.dart';
import 'finance/add_edit_preset_dialog.dart';
import 'finance/add_edit_transaction_sheet.dart';
import 'finance/budget_sheet.dart';
import 'finance/category_icon_helper.dart';
import 'finance/finance_preset.dart';
import 'finance/reconcile_wizard_screen.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TransactionType? _filterType;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<FinancePreset> _presets = FinancePreset.defaultPresets;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCustomPresets();
  }

  Future<void> _loadCustomPresets() async {
    final loaded = await FinancePreset.loadPresets();
    if (mounted) {
      setState(() => _presets = loaded);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {});
    ref.invalidate(summariesProvider);
  }

  Future<void> _addAccount() async {
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
      builder: (_) => const AddEditAccountDialog(),
    );

    if (result == null || !mounted) return;

    final repo = await ref.read(financeRepositoryProvider.future);
    await repo.addAccount(
      name: result.name,
      type: result.type,
      currencySymbol: result.currency,
      initialBalance: result.initialBalance,
      colorHex: result.colorHex,
      iconName: result.iconName,
    );
    _refresh();
  }

  Future<void> _addTransaction({
    String? preselectedAccountId,
    String? preselectedCategoryId,
    double? initialAmount,
    String? initialNote,
  }) async {
    final repo = await ref.read(financeRepositoryProvider.future);
    final accounts = await repo.getAccounts();
    final categories = await repo.getCategories();

    if (accounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create an account first before adding transactions'),
        ),
      );
      _addAccount();
      return;
    }

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
        preselectedAccountId: preselectedAccountId,
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

  Future<void> _quickLogPreset({
    required String label,
    required double defaultAmount,
    required String categoryKeyword,
    required List<Account> accounts,
    required List<FinanceCategory> categories,
  }) async {
    if (accounts.isEmpty) {
      _addAccount();
      return;
    }

    final category = categories.cast<FinanceCategory?>().firstWhere(
          (c) => c?.name.toLowerCase().contains(categoryKeyword.toLowerCase()) == true,
          orElse: () => categories.firstWhere((c) => c.type == CategoryType.expense),
        );

    await _addTransaction(
      preselectedAccountId: accounts.first.id,
      preselectedCategoryId: category?.id,
      initialAmount: defaultAmount,
      initialNote: label,
    );
  }

  Future<void> _addPreset(List<FinanceCategory> categories) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => AddEditPresetDialog(categories: categories),
    );

    if (result is FinancePreset && mounted) {
      final updated = List<FinancePreset>.from(_presets)..add(result);
      setState(() => _presets = updated);
      await FinancePreset.savePresets(updated);
    }
  }

  Future<void> _editPreset(
    FinancePreset preset,
    List<FinanceCategory> categories,
  ) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => AddEditPresetDialog(
        categories: categories,
        existing: preset,
      ),
    );

    if (!mounted) return;

    if (result == 'DELETE') {
      final updated = _presets.where((p) => p.id != preset.id).toList();
      setState(() => _presets = updated);
      await FinancePreset.savePresets(updated);
    } else if (result is FinancePreset) {
      final updated = _presets.map((p) => p.id == preset.id ? result : p).toList();
      setState(() => _presets = updated);
      await FinancePreset.savePresets(updated);
    }
  }

  Future<void> _setBudget(List<FinanceCategory> categories) async {
    final result = await showDialog<({String categoryId, double monthlyLimit})>(
      context: context,
      builder: (_) => SetBudgetDialog(categories: categories),
    );

    if (result == null || !mounted) return;

    final repo = await ref.read(financeRepositoryProvider.future);
    await repo.setBudget(
      categoryId: result.categoryId,
      monthlyLimit: result.monthlyLimit,
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Accounts', icon: Icon(Icons.account_balance_wallet_outlined)),
            Tab(text: 'Transactions', icon: Icon(Icons.receipt_long_outlined)),
            Tab(text: 'Budgets & Insights', icon: Icon(Icons.pie_chart_outline)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('financeMainFab'),
        onPressed: () {
          if (_tabController.index == 0) {
            _addAccount();
          } else {
            _addTransaction();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<(
        List<Account>,
        List<FinanceTransaction>,
        List<FinanceCategory>,
        NetWorth,
        MonthlyCashflow,
        List<CategoryBudget>,
        Map<String, double>
      )>(
        future: () async {
          final repo = await ref.read(financeRepositoryProvider.future);
          final accounts = await repo.getAccounts();
          final txs = await repo.getTransactions(limit: 200);
          final categories = await repo.getCategories();
          final netWorth = await repo.getNetWorth();
          final today = todayLocal();
          final cashflow = await repo.getMonthlyCashflow(today);
          final budgets = await repo.getBudgets();
          final spending = await repo.getMonthlyCategorySpending(today);
          return (accounts, txs, categories, netWorth, cashflow, budgets, spending);
        }(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final (
            accounts,
            transactions,
            categories,
            netWorth,
            cashflow,
            budgets,
            monthlySpending
          ) = snapshot.data!;

          final catById = {for (final c in categories) c.id: c};
          final accById = {for (final a in accounts) a.id: a};

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                // Top Net Worth & Cashflow Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Net Worth',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${accounts.length} ${accounts.length == 1 ? 'Account' : 'Accounts'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${netWorth.netWorth.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Assets: ₹${netWorth.assets.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (netWorth.liabilities > 0) ...[
                                const SizedBox(width: 12),
                                Text(
                                  'Liabilities: ₹${netWorth.liabilities.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'This Month\'s Cashflow',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.arrow_downward, size: 12, color: Colors.green.shade800),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Income',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '+₹${cashflow.income.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.arrow_upward, size: 12, color: Colors.red.shade800),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Expense',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '-₹${cashflow.expense.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.savings_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Savings',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${cashflow.netSavings.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: cashflow.netSavings >= 0
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: ACCOUNTS LIST
                      _buildAccountsTab(context, accounts),

                      // TAB 2: TRANSACTIONS LIST
                      _buildTransactionsTab(
                        context,
                        transactions,
                        categories,
                        accounts,
                        catById,
                        accById,
                      ),

                      // TAB 3: BUDGETS & INSIGHTS
                      _buildBudgetsTab(
                        context,
                        categories,
                        budgets,
                        monthlySpending,
                        cashflow,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountsTab(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No accounts created yet'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addAccount,
              icon: const Icon(Icons.add),
              label: const Text('Add Account'),
            ),
          ],
        ),
      );
    }

    final today = todayLocal();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final color = CategoryIconHelper.getColor(account.colorHex);
        final daysSinceReconcile = account.lastReconciledAt == null
            ? null
            : today.difference(account.lastReconciledAt!).inDays;

        final isReconciledHealthy =
            daysSinceReconcile != null && daysSinceReconcile < 7;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: color.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountDetailScreen(accountId: account.id),
                ),
              );
              _refresh();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Icon(
                          CategoryIconHelper.getIcon(account.iconName),
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              switch (account.type) {
                                AccountType.bank => 'Bank Account',
                                AccountType.cash => 'Cash Wallet',
                                AccountType.credit => 'Credit Card',
                                AccountType.savings => 'Savings',
                                AccountType.investment => 'Investment',
                              },
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${account.currencySymbol}${account.currentBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final changed = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => ReconcileWizardScreen(account: account),
                                ),
                              );
                              if (changed == true) _refresh();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isReconciledHealthy
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isReconciledHealthy
                                      ? Colors.green.shade300
                                      : Colors.orange.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isReconciledHealthy
                                        ? Icons.verified
                                        : Icons.sync_alt,
                                    size: 11,
                                    color: isReconciledHealthy
                                        ? Colors.green.shade800
                                        : Colors.orange.shade900,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    daysSinceReconcile == null
                                        ? 'Reconcile'
                                        : (daysSinceReconcile == 0
                                            ? 'Reconciled'
                                            : '${daysSinceReconcile}d ago'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isReconciledHealthy
                                          ? Colors.green.shade800
                                          : Colors.orange.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab(
    BuildContext context,
    List<FinanceTransaction> transactions,
    List<FinanceCategory> categories,
    List<Account> accounts,
    Map<String, FinanceCategory> catById,
    Map<String, Account> accById,
  ) {
    final filtered = transactions.where((t) {
      if (_filterType != null && t.type != _filterType) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final noteMatch = t.note?.toLowerCase().contains(q) == true;
        final catMatch = catById[t.categoryId]?.name.toLowerCase().contains(q) == true;
        final accMatch = accById[t.accountId]?.name.toLowerCase().contains(q) == true;
        if (!noteMatch && !catMatch && !accMatch) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Quick Presets 1-Tap Bar
        if (accounts.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Log Presets',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '1-Tap to Log · Hold to Edit',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        key: const Key('addCustomPresetChip'),
                        avatar: const Icon(Icons.add, size: 14),
                        label: const Text('Add Preset', style: TextStyle(fontWeight: FontWeight.w600)),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        onPressed: () => _addPreset(categories),
                      ),
                      const SizedBox(width: 8),
                      ..._presets.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onLongPress: () => _editPreset(preset, categories),
                            child: ActionChip(
                              avatar: Text(preset.emoji, style: const TextStyle(fontSize: 13)),
                              label: Text('${preset.name} ₹${preset.amount.toStringAsFixed(0)}'),
                              onPressed: () => _quickLogPreset(
                                label: preset.name,
                                defaultAmount: preset.amount,
                                categoryKeyword: preset.categoryKeyword,
                                accounts: accounts,
                                categories: categories,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Filter chips & Search Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
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
            ],
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filterType == null,
                onSelected: (_) => setState(() => _filterType = null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Expenses'),
                selected: _filterType == TransactionType.expense,
                onSelected: (_) => setState(() => _filterType = TransactionType.expense),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Income'),
                selected: _filterType == TransactionType.income,
                onSelected: (_) => setState(() => _filterType = TransactionType.income),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Transfers'),
                selected: _filterType == TransactionType.transfer,
                onSelected: (_) => setState(() => _filterType = TransactionType.transfer),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No transactions matching "$_searchQuery"'
                        : 'No transactions recorded',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final cat = catById[tx.categoryId];
                    final acc = accById[tx.accountId];
                    final toAcc = tx.toAccountId != null ? accById[tx.toAccountId] : null;
                    final color = CategoryIconHelper.getColor(cat?.colorHex);
                    final isExpense = tx.type == TransactionType.expense;
                    final isIncome = tx.type == TransactionType.income;
                    final currency = acc?.currencySymbol ?? '₹';

                    return Dismissible(
                      key: ValueKey('tx-${tx.id}'),
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
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(
                              CategoryIconHelper.getIcon(cat?.iconName),
                              color: color,
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
                            tx.type == TransactionType.transfer
                                ? '${acc?.name ?? ''} ➔ ${toAcc?.name ?? ''} · ${isoDate(tx.date)}'
                                : '${acc?.name ?? ''} · ${isoDate(tx.date)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Text(
                            '${isExpense ? '-' : (isIncome ? '+' : '')}$currency${tx.amount.toStringAsFixed(2)}',
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
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBudgetsTab(
    BuildContext context,
    List<FinanceCategory> categories,
    List<CategoryBudget> budgets,
    Map<String, double> spending,
    MonthlyCashflow cashflow,
  ) {
    final catById = {for (final c in categories) c.id: c};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Monthly Budgets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _setBudget(categories),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Set Budget'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (budgets.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No monthly category budgets set yet.'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _setBudget(categories),
                      icon: const Icon(Icons.add),
                      label: const Text('Set First Budget'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...budgets.map((b) {
            final cat = catById[b.categoryId];
            final color = CategoryIconHelper.getColor(cat?.colorHex);
            final spent = spending[b.categoryId] ?? 0.0;
            final progress = b.monthlyLimit > 0 ? (spent / b.monthlyLimit) : 0.0;
            final isOver = progress > 1.0;
            final isWarning = progress >= 0.85 && !isOver;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isOver
                      ? Colors.red.shade300
                      : (isWarning
                          ? Colors.orange.shade300
                          : Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.5)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: color.withValues(alpha: 0.2),
                          child: Icon(
                            CategoryIconHelper.getIcon(cat?.iconName),
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cat?.name ?? 'Category',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '₹${spent.toStringAsFixed(0)} / ₹${b.monthlyLimit.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isOver
                                ? Colors.red.shade700
                                : (isWarning ? Colors.orange.shade800 : null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          isOver
                              ? Colors.red
                              : (isWarning ? Colors.orange : Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOver
                          ? 'Exceeded by ₹${(spent - b.monthlyLimit).toStringAsFixed(0)}'
                          : '₹${(b.monthlyLimit - spent).toStringAsFixed(0)} remaining (${(progress * 100).toInt()}% used)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOver
                            ? Colors.red.shade700
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 24),
        Text(
          'Top Spending by Category',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (spending.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No expenses recorded this month.'),
              ),
            ),
          )
        else
          ...spending.entries.map((entry) {
            final cat = catById[entry.key];
            final color = CategoryIconHelper.getColor(cat?.colorHex);
            final totalExpense = cashflow.expense > 0 ? cashflow.expense : 1.0;
            final percent = ((entry.value / totalExpense) * 100).clamp(0, 100).toInt();

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(
                        CategoryIconHelper.getIcon(cat?.iconName),
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat?.name ?? 'Category',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '$percent% of monthly spending',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
