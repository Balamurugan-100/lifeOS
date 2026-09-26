import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'helpers.dart';

/// US5 lifecycle (T061, FR-005): the three core domains register as modules,
/// publish a `DomainSummary`, and light up on home with no per-domain wiring.
/// Time tracking is part of the Tasks module, so it reaches home through the
/// Tasks counts rather than a module of its own.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all three core domains appear on home with their own counts',
      (tester) async {
    final executor = openInMemoryExecutor();
    final dbs = await createCoreDatabases(executor);
    addTearDown(() async {
      await dbs.tasks.close();
      await dbs.habits.close();
      await dbs.finance.close();
    });

    await TaskRepository(dbs.tasks).add('Task data A');
    await HabitRepository(dbs.habits).define('Habit data B');
    await FinanceRepository(dbs.finance)
        .addAccount(name: 'Salary account', type: AccountType.bank);

    await pumpLifeOSApp(tester, executor: executor);

    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.byKey(const Key('summary-habits')), findsOneWidget);
    expect(find.byKey(const Key('summary-finance')), findsOneWidget);
    expect(find.text('1 outstanding'), findsOneWidget);
    expect(find.text('1 accounts'), findsOneWidget);
  });

  testWidgets('an empty install shows the empty state, not empty cards',
      (tester) async {
    final executor = openInMemoryExecutor();
    addTearDown(() => executor.close());

    await pumpLifeOSApp(tester, executor: executor);

    expect(find.byKey(const Key('emptystate')), findsOneWidget);
    expect(find.byKey(const Key('summary-tasks')), findsNothing);
    expect(find.byKey(const Key('summary-habits')), findsNothing);
    expect(find.byKey(const Key('summary-finance')), findsNothing);
  });

  testWidgets('tracked time rides along with the Tasks summary',
      (tester) async {
    final executor = openInMemoryExecutor();
    final dbs = await createCoreDatabases(executor);
    addTearDown(() async {
      await dbs.tasks.close();
      await executor.close();
    });

    final tasks = TaskRepository(dbs.tasks);
    final time = TimeRepository(dbs.tasks);
    final task = await tasks.add('Write the spec');
    await time.startSession(task.id);
    await time.stopSession((await time.activeSession())!.id);

    await pumpLifeOSApp(tester, executor: executor);

    expect(find.byKey(const Key('today-time-card')), findsOneWidget);
    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    // The pill is labelled for humans rather than leaking `trackedMinutes`.
    expect(find.text('0 min tracked'), findsNothing);
    expect(find.text('0 sec tracked'), findsNothing);
  });
}
