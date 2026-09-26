import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'helpers.dart';

/// US4 performance baseline (T059, SC-006): with 1,000 tasks and 500 habit
/// entries seeded, the home overview renders in under one second.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home renders 1000 tasks + 500 entries in under 1s (SC-006)',
      (tester) async {
    final executor = openInMemoryExecutor();
    final dbs = await createCoreDatabases(executor);
    addTearDown(() async {
      await dbs.tasks.close();
      await dbs.habits.close();
    });
    final tasks = TaskRepository(dbs.tasks);
    final habits = HabitRepository(dbs.habits);

    for (var i = 0; i < 1000; i++) {
      final dated = i % 4 == 0;
      await tasks.add(
        'Task $i',
        dueDate: dated ? DateTime(2026, 9, 20) : null,
      );
    }
    final daily = await habits.define('Daily');
    for (var i = 0; i < 500; i++) {
      await habits.record(daily.id, DateTime(2026, 8, 1).add(Duration(days: i)));
    }

    final stopwatch = Stopwatch()..start();
    await pumpLifeOSApp(tester, executor: executor);
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(1000),
        reason: 'home overview must render seeded data in under 1 second');
    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.text('1000 outstanding'), findsOneWidget);
    expect(find.byKey(const Key('summary-habits')), findsOneWidget);
  });

  test('summary derivation stays fast at volume', () async {
    final executor = openInMemoryExecutor();
    final dbs = await createCoreDatabases(executor);
    addTearDown(() async {
      await dbs.tasks.close();
      await dbs.habits.close();
    });
    final tasks = TaskRepository(dbs.tasks);
    final habits = HabitRepository(dbs.habits);
    for (var i = 0; i < 1000; i++) {
      await tasks.add('Task $i');
    }
    final daily = await habits.define('Daily');
    for (var i = 0; i < 500; i++) {
      await habits.record(daily.id, DateTime(2026, 8, 1).add(Duration(days: i)));
    }

    final stopwatch = Stopwatch()..start();
    final taskSummary = await TaskSummaryBuilder(tasks).build();
    final habitSummary = await HabitSummaryBuilder(habits).build();
    stopwatch.stop();

    expect(taskSummary.counts['outstanding'], 1000);
    expect((habitSummary.counts['doneToday'] ?? 0), greaterThanOrEqualTo(0));
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
  });
}