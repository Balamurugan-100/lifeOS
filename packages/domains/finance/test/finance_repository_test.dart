import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late FinanceDatabase database;
  late FinanceRepository repository;

  setUp(() async {
    database = FinanceDatabase(openInMemoryExecutor());
    // Trigger open / migrations
    await database.customSelect('SELECT 1').get();
    repository = FinanceRepository(database);
  });

  tearDown(() => database.close());

  group('Accounts & Balance Calculations', () {
    test('creates accounts and calculates balance correctly with transactions',
        () async {
      final bank = await repository.addAccount(
        name: 'HDFC Bank',
        type: AccountType.bank,
        initialBalance: 5000.0,
      );
      final cash = await repository.addAccount(
        name: 'Wallet',
        type: AccountType.cash,
        initialBalance: 500.0,
      );

      expect(bank.initialBalance, 5000.0);
      expect(bank.currentBalance, 5000.0);

      // Add expense from Bank
      await repository.addTransaction(
        accountId: bank.id,
        type: TransactionType.expense,
        categoryId: 'cat_groceries',
        amount: 1200.0,
        date: DateTime.utc(2026, 9, 1),
      );

      // Add income to Bank
      await repository.addTransaction(
        accountId: bank.id,
        type: TransactionType.income,
        categoryId: 'cat_salary',
        amount: 3000.0,
        date: DateTime.utc(2026, 9, 2),
      );

      // Transfer from Bank to Cash
      await repository.addTransaction(
        accountId: bank.id,
        toAccountId: cash.id,
        type: TransactionType.transfer,
        categoryId: 'cat_transfer',
        amount: 1000.0,
        date: DateTime.utc(2026, 9, 3),
      );

      final updatedBank = await repository.getAccountById(bank.id);
      final updatedCash = await repository.getAccountById(cash.id);

      // Bank: 5000 - 1200 + 3000 - 1000 = 5800
      expect(updatedBank!.currentBalance, 5800.0);
      // Cash: 500 + 1000 = 1500
      expect(updatedCash!.currentBalance, 1500.0);

      // Net worth: 5800 + 1500 = 7300
      final netWorth = await repository.getNetWorth();
      expect(netWorth.assets, 7300.0);
      expect(netWorth.netWorth, 7300.0);
    });

    test('deleting an account cleans up its transactions', () async {
      final account = await repository.addAccount(
        name: 'Test Account',
        type: AccountType.savings,
        initialBalance: 1000.0,
      );

      await repository.addTransaction(
        accountId: account.id,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        amount: 250.0,
        date: DateTime.utc(2026, 9, 10),
      );

      expect(await repository.getTransactions(accountId: account.id), hasLength(1));

      await repository.deleteAccount(account.id);

      expect(await repository.getAccountById(account.id), isNull);
      expect(await repository.getTransactions(accountId: account.id), isEmpty);
    });
  });

  group('Reconciliation Flow ("Catch-Up & Reconcile")', () {
    test('computes discrepancy delta accurately', () async {
      final account = await repository.addAccount(
        name: 'Checking',
        type: AccountType.bank,
        initialBalance: 2000.0,
      );

      // Log an expense of 500 -> calculated balance is 1500
      await repository.addTransaction(
        accountId: account.id,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        amount: 500.0,
        date: DateTime.utc(2026, 9, 5),
      );

      // User checks actual bank app which shows 1100 (discrepancy: 1100 - 1500 = -400 unrecorded expense)
      final delta = await repository.getReconciliationDelta(account.id, 1100.0);
      expect(delta.calculatedBalance, 1500.0);
      expect(delta.discrepancy, -400.0);

      // User adds a missing transaction of 250
      await repository.addTransaction(
        accountId: account.id,
        type: TransactionType.expense,
        categoryId: 'cat_groceries',
        amount: 250.0,
        date: DateTime.utc(2026, 9, 6),
      );

      // New delta: calculated is 1250, actual is 1100 -> discrepancy is now -150
      final delta2 = await repository.getReconciliationDelta(account.id, 1100.0);
      expect(delta2.calculatedBalance, 1250.0);
      expect(delta2.discrepancy, -150.0);

      // Finalize reconciliation with adjustment for remaining -150
      final record = await repository.completeReconciliation(
        accountId: account.id,
        statementBalance: 1100.0,
        adjustmentAmount: -150.0,
        note: 'Catch-up balance adjustment',
      );

      expect(record.statementBalance, 1100.0);
      expect(record.adjustmentAmount, -150.0);

      // Final calculated balance must match actual statement balance (1100.0)
      final finalAccount = await repository.getAccountById(account.id);
      expect(finalAccount!.currentBalance, 1100.0);
      expect(finalAccount.lastReconciledAt, isNotNull);
    });
  });

  group('Budgets and Analytics', () {
    test('tracks category budgets and monthly spending', () async {
      final account = await repository.addAccount(
        name: 'Main',
        type: AccountType.bank,
        initialBalance: 10000.0,
      );

      await repository.setBudget(
        categoryId: 'cat_food',
        monthlyLimit: 3000.0,
      );

      final budgets = await repository.getBudgets();
      expect(budgets, hasLength(1));
      expect(budgets.first.monthlyLimit, 3000.0);

      // Add expense for September 2026
      await repository.addTransaction(
        accountId: account.id,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        amount: 1500.0,
        date: DateTime.utc(2026, 9, 15),
      );

      final sepSpending = await repository.getMonthlyCategorySpending(DateTime.utc(2026, 9, 1));
      expect(sepSpending['cat_food'], 1500.0);

      final cashflow = await repository.getMonthlyCashflow(DateTime.utc(2026, 9, 1));
      expect(cashflow.expense, 1500.0);
      expect(cashflow.netSavings, -1500.0);
    });
  });
}
