import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/finance_screen.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _financeApp({required QueryExecutor executor}) {
  return ProviderScope(
    overrides: [
      databaseExecutorProvider.overrideWith((ref) async => executor),
    ],
    child: const MaterialApp(
      home: FinanceScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Finance screen renders empty state and allows creating account',
      (tester) async {
    final executor = openInMemoryExecutor();
    await tester.pumpWidget(_financeApp(executor: executor));
    await tester.pumpAndSettle();

    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('No accounts created yet'), findsOneWidget);

    // Open Add Account dialog
    await tester.tap(find.text('Add Account'));
    await tester.pumpAndSettle();

    expect(find.text('Account Name'), findsOneWidget);

    // Fill account name
    await tester.enterText(
        find.byKey(const Key('accountNameField')), 'HDFC Savings');
    await tester.enterText(
        find.byKey(const Key('accountInitialBalanceField')), '10000');

    await tester.tap(find.byKey(const Key('saveAccountBtn')));
    await tester.pumpAndSettle();

    // Verify account is listed
    expect(find.text('HDFC Savings'), findsOneWidget);
    expect(find.text('₹10000.00'), findsWidgets);
  });

  testWidgets('Finance screen allows adding transactions and computes cashflow',
      (tester) async {
    final executor = openInMemoryExecutor();
    final db = FinanceDatabase(executor);
    await db.ensureTables();
    final repo = FinanceRepository(db);

    await repo.addAccount(
      name: 'Main Bank',
      type: AccountType.bank,
      initialBalance: 5000,
    );

    await tester.pumpWidget(_financeApp(executor: executor));
    await tester.pumpAndSettle();

    expect(find.text('Main Bank'), findsOneWidget);

    // Switch to Transactions tab
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    expect(find.text('No transactions recorded'), findsOneWidget);

    // Tap main FAB to add transaction
    await tester.tap(find.byKey(const Key('financeMainFab')));
    await tester.pumpAndSettle();

    // Enter transaction amount
    await tester.enterText(
        find.byKey(const Key('transactionAmountField')), '750');
    await tester.enterText(
        find.byKey(const Key('transactionNoteField')), 'Dinner at cafe');

    await tester.tap(find.byKey(const Key('saveTransactionBtn')));
    await tester.pumpAndSettle();

    // Verify transaction appears
    expect(find.text('Dinner at cafe'), findsOneWidget);
    expect(find.text('-₹750.00'), findsOneWidget);
  });

  testWidgets('Balance Reconcile Wizard accurately tracks discrepancy and adjusts',
      (tester) async {
    final executor = openInMemoryExecutor();
    final db = FinanceDatabase(executor);
    await db.ensureTables();
    final repo = FinanceRepository(db);

    await repo.addAccount(
      name: 'Checking Account',
      type: AccountType.bank,
      initialBalance: 3000,
    );

    // Initial recorded balance is 3000
    await tester.pumpWidget(_financeApp(executor: executor));
    await tester.pumpAndSettle();

    // Tap account to open AccountDetailScreen
    await tester.tap(find.text('Checking Account'));
    await tester.pumpAndSettle();

    expect(find.text('Never reconciled'), findsOneWidget);

    // Open Reconcile Wizard
    await tester.tap(find.byKey(const Key('openReconcileBtn')));
    await tester.pumpAndSettle();

    expect(find.text('Reconcile Balance'), findsOneWidget);
    expect(find.textContaining('LifeOS Recorded Balance: ₹3000.00'), findsOneWidget);

    // Enter actual statement balance: 2500 (difference: -500)
    await tester.enterText(
        find.byKey(const Key('actualBalanceInput')), '2500');
    await tester.pumpAndSettle();

    expect(find.textContaining('Difference to Reconcile: ₹500.00'), findsOneWidget);
    expect(find.byKey(const Key('adjustBalanceBtn')), findsOneWidget);

    // Ensure button is visible in scroll view and tap
    await tester.ensureVisible(find.byKey(const Key('adjustBalanceBtn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adjustBalanceBtn')));
    await tester.pumpAndSettle();

    // Reconcile complete - account detail screen now shows 2500 balance and reconciled today
    expect(find.text('₹2500.00'), findsWidgets);
    expect(find.text('Reconciled today'), findsOneWidget);
  });

  testWidgets(
      'Reconcile Wizard allows multi-transaction catch-up until target discrepancy is zero',
      (tester) async {
    final executor = openInMemoryExecutor();
    final db = FinanceDatabase(executor);
    await db.ensureTables();
    final repo = FinanceRepository(db);

    await repo.addAccount(
      name: 'Wallet',
      type: AccountType.cash,
      initialBalance: 1000,
    );

    // Initial balance is 1000
    await tester.pumpWidget(_financeApp(executor: executor));
    await tester.pumpAndSettle();

    // Open Wallet account detail
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    // Open Reconcile
    await tester.tap(find.byKey(const Key('openReconcileBtn')));
    await tester.pumpAndSettle();

    // Actual balance is 700 (Target discrepancy: -300)
    // Testing input sanitization with formatting spaces like '700 .00'
    await tester.enterText(
        find.byKey(const Key('actualBalanceInput')), '700.00');
    await tester.pumpAndSettle();

    expect(find.textContaining('Difference to Reconcile: ₹300.00'), findsOneWidget);

    // Item 1: 200 on dinner
    await tester.ensureVisible(find.byKey(const Key('catchUpAmountInput')));
    await tester.enterText(
        find.byKey(const Key('catchUpAmountInput')), '200');
    await tester.enterText(
        find.byKey(const Key('catchUpNoteInput')), 'dinner');
    await tester.ensureVisible(find.byKey(const Key('addCatchUpTxBtn')));
    await tester.tap(find.byKey(const Key('addCatchUpTxBtn')));
    await tester.pumpAndSettle();

    // Now discrepancy is 100
    expect(find.textContaining('Difference to Reconcile: ₹100.00'), findsOneWidget);
    expect(find.text('dinner'), findsOneWidget);

    // Item 2: 40 on tea
    await tester.ensureVisible(find.byKey(const Key('catchUpAmountInput')));
    await tester.enterText(
        find.byKey(const Key('catchUpAmountInput')), '40');
    await tester.enterText(
        find.byKey(const Key('catchUpNoteInput')), 'tea');
    await tester.ensureVisible(find.byKey(const Key('addCatchUpTxBtn')));
    await tester.tap(find.byKey(const Key('addCatchUpTxBtn')));
    await tester.pumpAndSettle();

    // Now discrepancy is 60
    expect(find.textContaining('Difference to Reconcile: ₹60.00'), findsOneWidget);
    expect(find.text('tea'), findsOneWidget);

    // Item 3: 60 on snacks
    await tester.ensureVisible(find.byKey(const Key('catchUpAmountInput')));
    await tester.enterText(
        find.byKey(const Key('catchUpAmountInput')), '60');
    await tester.enterText(
        find.byKey(const Key('catchUpNoteInput')), 'snacks');
    await tester.ensureVisible(find.byKey(const Key('addCatchUpTxBtn')));
    await tester.tap(find.byKey(const Key('addCatchUpTxBtn')));
    await tester.pumpAndSettle();

    // Now discrepancy is 0 -> Balance matches perfectly!
    expect(find.textContaining('Balance Matches Perfectly!'), findsOneWidget);
    expect(find.byKey(const Key('confirmReconcileBtn')), findsOneWidget);

    // Tap Complete Reconciliation
    await tester.ensureVisible(find.byKey(const Key('confirmReconcileBtn')));
    await tester.tap(find.byKey(const Key('confirmReconcileBtn')));
    await tester.pumpAndSettle();

    // Account Detail shows updated balance of ₹700.00
    expect(find.text('₹700.00'), findsWidgets);
    expect(find.text('Reconciled today'), findsOneWidget);
  });
}

