import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightAction, HighlightedItem, todayLocal;

import 'models/category.dart';
import 'repositories/finance_repository.dart';

/// Builds the Finance domain contribution to the home overview.
class FinanceSummaryBuilder {
  FinanceSummaryBuilder(this._repository);

  final FinanceRepository _repository;

  Future<DomainSummary> build({DateTime? today}) async {
    final now = today ?? todayLocal();
    final accounts = await _repository.getAccounts(includeArchived: false);

    if (accounts.isEmpty) {
      return DomainSummary(
        domainKey: 'finance',
        displayName: 'Finance',
        counts: {
          'accounts': 0,
          'expenses': 0,
          'needsReconciliation': 0,
        },
        highlighted: const [],
        refreshedAt: DateTime.now().toUtc(),
      );
    }

    final cashflow = await _repository.getMonthlyCashflow(now);
    final budgets = await _repository.getBudgets();
    final spending = await _repository.getMonthlyCategorySpending(now);
    final categories = await _repository.getCategories();
    final catById = {for (final c in categories) c.id: c};

    final highlighted = <HighlightedItem>[];

    // 1. Highlight accounts needing reconciliation (> 14 days or never reconciled)
    int unreconciledCount = 0;
    for (final acc in accounts) {
      final daysSinceReconciled = acc.lastReconciledAt == null
          ? 999
          : now.difference(acc.lastReconciledAt!).inDays;

      if (daysSinceReconciled >= 14) {
        unreconciledCount++;
        if (highlighted.length < 3) {
          highlighted.add(
            HighlightedItem(
              id: acc.id,
              kind: 'finance.reconcile',
              title: 'Reconcile ${acc.name}',
              subtitle: acc.lastReconciledAt == null
                  ? 'Never reconciled'
                  : 'Reconciled $daysSinceReconciled days ago',
              action: HighlightAction.openDomain,
            ),
          );
        }
      }
    }

    // 2. Highlight categories nearing or over budget (> 85%)
    for (final b in budgets) {
      final spent = spending[b.categoryId] ?? 0.0;
      final pct = b.monthlyLimit > 0 ? (spent / b.monthlyLimit) : 0.0;
      final cat = catById[b.categoryId] ??
          FinanceCategory(
            id: b.categoryId,
            name: 'Category',
            type: CategoryType.expense,
            iconName: 'category',
            colorHex: '#9E9E9E',
            createdAt: now,
          );

      if (pct >= 0.85 && highlighted.length < 3) {
        final pctFormatted = (pct * 100).toInt();
        highlighted.add(
          HighlightedItem(
            id: b.id,
            kind: 'finance.budget',
            title: '${cat.name} budget at $pctFormatted%',
            subtitle:
                'Spent ${spent.toStringAsFixed(0)} of ${b.monthlyLimit.toStringAsFixed(0)}',
            action: HighlightAction.openDomain,
          ),
        );
      }
    }

    return DomainSummary(
      domainKey: 'finance',
      displayName: 'Finance',
      counts: {
        'accounts': accounts.length,
        'thisMonthExpense': cashflow.expense.toInt(),
        'needsReconciliation': unreconciledCount,
      },
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
