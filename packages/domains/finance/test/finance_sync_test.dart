import 'package:test/test.dart';
import 'package:lifeos_core/lifeos_core.dart' show todayLocal;
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  test('FinanceRepository calculates account balance, cashflow and net worth in sync',
      () async {
    final executor = openInMemoryExecutor();
    final db = FinanceDatabase(executor);
    await db.ensureTables();
    final repo = FinanceRepository(db);

    // 1. Create Bank Account 'test' with starting balance 199,000
    final account = await repo.addAccount(
      name: 'test',
      type: AccountType.bank,
      initialBalance: 199000,
    );

    // Initial check
    var accounts = await repo.getAccounts();
    expect(accounts.length, 1);
    expect(accounts.first.currentBalance, 199000.0);

    var netWorth = await repo.getNetWorth();
    expect(netWorth.assets, 199000.0);
    expect(netWorth.liabilities, 0.0);
    expect(netWorth.netWorth, 199000.0);

    // 2. Add income transaction of 100 this month
    final today = todayLocal();
    await repo.addTransaction(
      accountId: account.id,
      type: TransactionType.income,
      categoryId: 'cat_salary',
      amount: 100,
      date: today,
      note: 'Freelance test',
    );

    // Account balance should now be 199,100
    final balanceAfterIncome = await repo.calculateAccountBalance(account.id);
    expect(balanceAfterIncome, 199100.0);

    // Monthly cashflow should show Income: 100, Expense: 0, Net Savings: 100
    final cashflow = await repo.getMonthlyCashflow(today);
    expect(cashflow.income, 100.0);
    expect(cashflow.expense, 0.0);
    expect(cashflow.netSavings, 100.0);

    // Net Worth MUST BE 199,100 (Total Assets)
    netWorth = await repo.getNetWorth();
    expect(netWorth.assets, 199100.0);
    expect(netWorth.netWorth, 199100.0);

    // 3. Reconcile with actual statement balance 199,100 (Zero discrepancy)
    final rec = await repo.completeReconciliation(
      accountId: account.id,
      statementBalance: 199100.0,
      adjustmentAmount: 0.0,
    );
    expect(rec.discrepancy, 0.0);

    // Account balance and net worth should remain 199,100
    accounts = await repo.getAccounts();
    expect(accounts.first.currentBalance, 199100.0);

    netWorth = await repo.getNetWorth();
    expect(netWorth.netWorth, 199100.0);
  });

  test('Reconciliation with discrepancy auto-adjustment updates balance and net worth',
      () async {
    final executor = openInMemoryExecutor();
    final db = FinanceDatabase(executor);
    await db.ensureTables();
    final repo = FinanceRepository(db);

    // Start with balance 100
    final account = await repo.addAccount(
      name: 'test',
      type: AccountType.bank,
      initialBalance: 100,
    );

    // User finds actual statement is 199,100 (Discrepancy: +199,000)
    final delta = await repo.getReconciliationDelta(account.id, 199100.0);
    expect(delta.discrepancy, 199000.0);

    // Reconcile and adjust
    await repo.completeReconciliation(
      accountId: account.id,
      statementBalance: 199100.0,
      adjustmentAmount: 199000.0,
    );

    // Account balance should now be exactly 199,100
    final balance = await repo.calculateAccountBalance(account.id);
    expect(balance, 199100.0);

    // Net worth should now be exactly 199,100
    final netWorth = await repo.getNetWorth();
    expect(netWorth.netWorth, 199100.0);
  });
}
