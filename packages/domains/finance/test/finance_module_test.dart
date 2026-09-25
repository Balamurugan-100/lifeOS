import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late FinanceDatabase database;
  late FinanceRepository repository;
  late FinanceModule module;

  setUp(() async {
    database = FinanceDatabase(openInMemoryExecutor());
    await database.customSelect('SELECT 1').get();
    repository = FinanceRepository(database);
    module = FinanceModule(database);
  });

  tearDown(() => database.close());

  group('FinanceModule & Summary', () {
    test('empty state returns zero counts and no highlights', () async {
      final summary = await module.buildSummary();

      expect(summary.domainKey, 'finance');
      expect(summary.displayName, 'Finance');
      expect(summary.isEmpty, isTrue);
      expect(summary.highlighted, isEmpty);
    });

    test('highlights account needing reconciliation', () async {
      await repository.addAccount(
        name: 'SBI Bank',
        type: AccountType.bank,
        initialBalance: 5000.0,
      );

      final summary = await module.buildSummary();
      expect(summary.isEmpty, isFalse);
      expect(summary.counts['accounts'], 1);
      expect(summary.highlighted, isNotEmpty);
      expect(summary.highlighted.first.kind, 'finance.reconcile');
      expect(summary.highlighted.first.title, 'Reconcile SBI Bank');
      expect(summary.highlighted.first.action, HighlightAction.openDomain);
    });

    test('highlights category exceeding 85% budget', () async {
      final acc = await repository.addAccount(
        name: 'Checking',
        type: AccountType.bank,
        initialBalance: 10000.0,
      );
      // Set reconciled date to today to avoid reconcile highlight
      await repository.completeReconciliation(
        accountId: acc.id,
        statementBalance: 10000.0,
        adjustmentAmount: 0.0,
      );

      await repository.setBudget(
        categoryId: 'cat_food',
        monthlyLimit: 1000.0,
      );

      // Spend 900 (90%)
      await repository.addTransaction(
        accountId: acc.id,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        amount: 900.0,
        date: DateTime.now(),
      );

      final summary = await module.buildSummary();
      expect(summary.highlighted, isNotEmpty);
      expect(summary.highlighted.first.kind, 'finance.budget');
      expect(summary.highlighted.first.title, contains('Food & Dining budget at 90%'));
    });
  });
}
