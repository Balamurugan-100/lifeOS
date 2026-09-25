import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart' show newId;
import 'package:lifeos_storage/lifeos_storage.dart' show utcNow;

import '../database/finance_database.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/reconciliation.dart';
import '../models/transaction.dart';

/// Net worth breakdown record.
class NetWorth {
  const NetWorth({
    required this.assets,
    required this.liabilities,
    required this.netWorth,
  });

  final double assets;
  final double liabilities;
  final double netWorth;
}

/// Monthly cashflow record.
class MonthlyCashflow {
  const MonthlyCashflow({
    required this.income,
    required this.expense,
    required this.netSavings,
  });

  final double income;
  final double expense;
  final double netSavings;
}

/// Repository managing finance data operations, calculations, reconciliation, and analytics.
class FinanceRepository {
  FinanceRepository(this._db);

  final FinanceDatabase _db;

  // ==========================================
  // ACCOUNTS
  // ==========================================

  Future<Account> addAccount({
    required String name,
    required AccountType type,
    String currencySymbol = '₹',
    double initialBalance = 0.0,
    String? colorHex,
    String? iconName,
  }) async {
    final id = newId();
    final now = utcNow();

    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            name: name,
            type: type.name,
            currencySymbol: Value(currencySymbol),
            initialBalance: Value(initialBalance),
            colorHex: Value(colorHex),
            iconName: Value(iconName),
            isArchived: const Value(false),
            lastReconciledAt: const Value(null),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return Account(
      id: id,
      name: name,
      type: type,
      currencySymbol: currencySymbol,
      initialBalance: initialBalance,
      currentBalance: initialBalance,
      colorHex: colorHex,
      iconName: iconName,
      isArchived: false,
      lastReconciledAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateAccount(
    String id, {
    String? name,
    AccountType? type,
    String? currencySymbol,
    double? initialBalance,
    String? colorHex,
    String? iconName,
  }) async {
    final now = utcNow();
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id))).write(
      AccountsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type.name) : const Value.absent(),
        currencySymbol:
            currencySymbol != null ? Value(currencySymbol) : const Value.absent(),
        initialBalance:
            initialBalance != null ? Value(initialBalance) : const Value.absent(),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        iconName: iconName != null ? Value(iconName) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> setAccountArchived(String id, bool isArchived) async {
    final now = utcNow();
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(id))).write(
      AccountsCompanion(
        isArchived: Value(isArchived),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteAccount(String id) async {
    // Delete all associated transactions first
    await (_db.delete(_db.financeTransactions)
          ..where((tbl) => tbl.accountId.equals(id) | tbl.toAccountId.equals(id)))
        .go();
    // Delete reconciliation records
    await (_db.delete(_db.reconciliationRecords)
          ..where((tbl) => tbl.accountId.equals(id)))
        .go();
    // Delete account
    await (_db.delete(_db.accounts)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<Account?> getAccountById(String id) async {
    final row = await (_db.select(_db.accounts)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final balance = await calculateAccountBalance(id);
    return _mapAccount(row, balance);
  }

  Future<List<Account>> getAccounts({bool includeArchived = false}) async {
    var query = _db.select(_db.accounts);
    if (!includeArchived) {
      query = query..where((tbl) => tbl.isArchived.equals(false));
    }
    query = query
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc),
      ]);

    final rows = await query.get();
    final result = <Account>[];
    for (final row in rows) {
      final balance = await calculateAccountBalance(row.id);
      result.add(_mapAccount(row, balance));
    }
    return result;
  }

  Future<double> calculateAccountBalance(String accountId) async {
    final account = await (_db.select(_db.accounts)
          ..where((tbl) => tbl.id.equals(accountId)))
        .getSingleOrNull();
    if (account == null) return 0.0;

    double balance = account.initialBalance;

    // Get all transactions for this account
    final txs = await (_db.select(_db.financeTransactions)
          ..where((tbl) =>
              tbl.accountId.equals(accountId) |
              tbl.toAccountId.equals(accountId)))
        .get();

    for (final tx in txs) {
      if (tx.accountId == accountId) {
        if (tx.type == TransactionType.income.name) {
          balance += tx.amount;
        } else if (tx.type == TransactionType.expense.name) {
          balance -= tx.amount;
        } else if (tx.type == TransactionType.transfer.name) {
          balance -= tx.amount;
        }
      } else if (tx.toAccountId == accountId) {
        if (tx.type == TransactionType.transfer.name) {
          balance += tx.amount;
        }
      }
    }

    return balance;
  }

  Future<NetWorth> getNetWorth() async {
    final accounts = await getAccounts(includeArchived: false);
    double assets = 0.0;
    double liabilities = 0.0;

    for (final acc in accounts) {
      if (acc.type == AccountType.credit) {
        if (acc.currentBalance < 0) {
          liabilities += acc.currentBalance.abs();
        } else {
          // If credit card has positive balance / overpayment, consider as asset
          assets += acc.currentBalance;
        }
      } else {
        if (acc.currentBalance >= 0) {
          assets += acc.currentBalance;
        } else {
          liabilities += acc.currentBalance.abs();
        }
      }
    }

    return NetWorth(
      assets: assets,
      liabilities: liabilities,
      netWorth: assets - liabilities,
    );
  }

  // ==========================================
  // CATEGORIES
  // ==========================================

  Future<List<FinanceCategory>> getCategories({CategoryType? type}) async {
    var query = _db.select(_db.financeCategories);
    if (type != null) {
      query = query..where((tbl) => tbl.type.equals(type.name));
    }
    query = query
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.name, mode: OrderingMode.asc),
      ]);

    final rows = await query.get();
    return rows
        .map(
          (r) => FinanceCategory(
            id: r.id,
            name: r.name,
            type: CategoryType.fromString(r.type),
            iconName: r.iconName,
            colorHex: r.colorHex,
            isPredefined: r.isPredefined,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  Future<FinanceCategory> addCategory({
    required String name,
    required CategoryType type,
    required String iconName,
    required String colorHex,
  }) async {
    final id = newId();
    final now = utcNow();

    await _db.into(_db.financeCategories).insert(
          FinanceCategoriesCompanion.insert(
            id: id,
            name: name,
            type: type.name,
            iconName: iconName,
            colorHex: colorHex,
            isPredefined: const Value(false),
            createdAt: now,
          ),
        );

    return FinanceCategory(
      id: id,
      name: name,
      type: type,
      iconName: iconName,
      colorHex: colorHex,
      isPredefined: false,
      createdAt: now,
    );
  }

  Future<void> deleteCategory(String id) async {
    await (_db.delete(_db.financeCategories)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // ==========================================
  // TRANSACTIONS
  // ==========================================

  Future<FinanceTransaction> addTransaction({
    required String accountId,
    String? toAccountId,
    required TransactionType type,
    required String categoryId,
    required double amount,
    required DateTime date,
    String? note,
    bool isReconciliationAdjustment = false,
  }) async {
    final id = newId();
    final now = utcNow();

    await _db.into(_db.financeTransactions).insert(
          FinanceTransactionsCompanion.insert(
            id: id,
            accountId: accountId,
            toAccountId: Value(toAccountId),
            type: type.name,
            categoryId: categoryId,
            amount: amount,
            date: date,
            note: Value(note),
            isReconciliationAdjustment: Value(isReconciliationAdjustment),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return FinanceTransaction(
      id: id,
      accountId: accountId,
      toAccountId: toAccountId,
      type: type,
      categoryId: categoryId,
      amount: amount,
      date: date,
      note: note,
      isReconciliationAdjustment: isReconciliationAdjustment,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateTransaction(
    String id, {
    String? accountId,
    String? toAccountId,
    TransactionType? type,
    String? categoryId,
    double? amount,
    DateTime? date,
    String? note,
  }) async {
    final now = utcNow();
    await (_db.update(_db.financeTransactions)..where((tbl) => tbl.id.equals(id)))
        .write(
      FinanceTransactionsCompanion(
        accountId: accountId != null ? Value(accountId) : const Value.absent(),
        toAccountId: Value(toAccountId),
        type: type != null ? Value(type.name) : const Value.absent(),
        categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
        amount: amount != null ? Value(amount) : const Value.absent(),
        date: date != null ? Value(date) : const Value.absent(),
        note: note != null ? Value(note) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteTransaction(String id) async {
    await (_db.delete(_db.financeTransactions)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  Future<FinanceTransaction?> getTransactionById(String id) async {
    final r = await (_db.select(_db.financeTransactions)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (r == null) return null;
    return _mapTransaction(r);
  }

  Future<List<FinanceTransaction>> getTransactions({
    String? accountId,
    String? categoryId,
    TransactionType? type,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 150,
  }) async {
    var query = _db.select(_db.financeTransactions);

    if (accountId != null) {
      query = query
        ..where((tbl) =>
            tbl.accountId.equals(accountId) |
            tbl.toAccountId.equals(accountId));
    }
    if (categoryId != null) {
      query = query..where((tbl) => tbl.categoryId.equals(categoryId));
    }
    if (type != null) {
      query = query..where((tbl) => tbl.type.equals(type.name));
    }
    if (fromDate != null) {
      query = query..where((tbl) => tbl.date.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      query = query..where((tbl) => tbl.date.isSmallerOrEqualValue(toDate));
    }

    query = query
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc),
        (tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_mapTransaction).toList();
  }

  // ==========================================
  // RECONCILIATION ("CATCH-UP & RECONCILE")
  // ==========================================

  /// Computes the difference between user's actual statement balance and the calculated balance.
  /// Discrepancy = statementBalance - calculatedBalance.
  /// (Negative means actual has less money -> unrecorded expenses.
  /// Positive means actual has more money -> unrecorded income).
  Future<({double calculatedBalance, double discrepancy})>
      getReconciliationDelta(String accountId, double statementBalance) async {
    final calculated = await calculateAccountBalance(accountId);
    final discrepancy = statementBalance - calculated;
    return (calculatedBalance: calculated, discrepancy: discrepancy);
  }

  /// Finalizes reconciliation for an account.
  /// If [adjustmentAmount] is non-zero, creates a balancing adjustment transaction.
  Future<ReconciliationRecord> completeReconciliation({
    required String accountId,
    required double statementBalance,
    required double adjustmentAmount,
    String? note,
  }) async {
    final now = utcNow();
    final calculatedBefore = await calculateAccountBalance(accountId);
    final discrepancy = statementBalance - calculatedBefore;

    // If adjustment amount is provided and non-zero, create a balancing transaction
    if (adjustmentAmount != 0.0) {
      final isIncomeAdjustment = adjustmentAmount > 0;
      await addTransaction(
        accountId: accountId,
        type: isIncomeAdjustment
            ? TransactionType.income
            : TransactionType.expense,
        categoryId: 'cat_adjustment',
        amount: adjustmentAmount.abs(),
        date: now,
        note: note ?? 'Balance reconciliation adjustment',
        isReconciliationAdjustment: true,
      );
    }

    // Update account lastReconciledAt timestamp
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
        .write(
      AccountsCompanion(
        lastReconciledAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Save reconciliation audit record
    final recId = newId();
    await _db.into(_db.reconciliationRecords).insert(
          ReconciliationRecordsCompanion.insert(
            id: recId,
            accountId: accountId,
            statementBalance: statementBalance,
            calculatedBalanceBefore: calculatedBefore,
            discrepancy: discrepancy,
            adjustmentAmount: adjustmentAmount,
            reconciledAt: now,
          ),
        );

    return ReconciliationRecord(
      id: recId,
      accountId: accountId,
      statementBalance: statementBalance,
      calculatedBalanceBefore: calculatedBefore,
      discrepancy: discrepancy,
      adjustmentAmount: adjustmentAmount,
      reconciledAt: now,
    );
  }

  // ==========================================
  // BUDGETS & ANALYTICS
  // ==========================================

  Future<void> setBudget({
    required String categoryId,
    required double monthlyLimit,
  }) async {
    final existing = await (_db.select(_db.categoryBudgets)
          ..where((tbl) => tbl.categoryId.equals(categoryId)))
        .getSingleOrNull();

    final now = utcNow();
    if (existing == null) {
      final id = newId();
      await _db.into(_db.categoryBudgets).insert(
            CategoryBudgetsCompanion.insert(
              id: id,
              categoryId: categoryId,
              monthlyLimit: monthlyLimit,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(_db.categoryBudgets)
            ..where((tbl) => tbl.id.equals(existing.id)))
          .write(
        CategoryBudgetsCompanion(
          monthlyLimit: Value(monthlyLimit),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> deleteBudget(String id) async {
    await (_db.delete(_db.categoryBudgets)..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  Future<List<CategoryBudget>> getBudgets() async {
    final rows = await _db.select(_db.categoryBudgets).get();
    return rows
        .map(
          (r) => CategoryBudget(
            id: r.id,
            categoryId: r.categoryId,
            monthlyLimit: r.monthlyLimit,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  Future<MonthlyCashflow> getMonthlyCashflow(DateTime month) async {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 0, 23, 59, 59);

    final txs = await (_db.select(_db.financeTransactions)
          ..where((tbl) =>
              tbl.date.isBiggerOrEqualValue(startOfMonth) &
              tbl.date.isSmallerOrEqualValue(endOfMonth)))
        .get();

    double income = 0.0;
    double expense = 0.0;

    for (final tx in txs) {
      if (tx.type == TransactionType.income.name) {
        income += tx.amount;
      } else if (tx.type == TransactionType.expense.name) {
        expense += tx.amount;
      }
    }

    return MonthlyCashflow(
      income: income,
      expense: expense,
      netSavings: income - expense,
    );
  }

  Future<Map<String, double>> getMonthlyCategorySpending(DateTime month) async {
    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 0, 23, 59, 59);

    final txs = await (_db.select(_db.financeTransactions)
          ..where((tbl) =>
              tbl.type.equals(TransactionType.expense.name) &
              tbl.date.isBiggerOrEqualValue(startOfMonth) &
              tbl.date.isSmallerOrEqualValue(endOfMonth)))
        .get();

    final spending = <String, double>{};
    for (final tx in txs) {
      spending[tx.categoryId] = (spending[tx.categoryId] ?? 0.0) + tx.amount;
    }
    return spending;
  }

  // ==========================================
  // HELPERS & MAPPERS
  // ==========================================

  Account _mapAccount(AccountEntry r, double balance) {
    return Account(
      id: r.id,
      name: r.name,
      type: AccountType.fromString(r.type),
      currencySymbol: r.currencySymbol,
      initialBalance: r.initialBalance,
      currentBalance: balance,
      colorHex: r.colorHex,
      iconName: r.iconName,
      isArchived: r.isArchived,
      lastReconciledAt: r.lastReconciledAt,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  FinanceTransaction _mapTransaction(TransactionEntry r) {
    return FinanceTransaction(
      id: r.id,
      accountId: r.accountId,
      toAccountId: r.toAccountId,
      type: TransactionType.fromString(r.type),
      categoryId: r.categoryId,
      amount: r.amount,
      date: r.date,
      note: r.note,
      isReconciliationAdjustment: r.isReconciliationAdjustment,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }
}
