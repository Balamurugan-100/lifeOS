import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'helpers.dart';

/// US3 independent test (T055): habits coexist with tasks without any
/// cross-domain effect; define a habit with a preset schedule, record
/// completions, streaks render, and the habit summary shows on home.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'habits work alongside tasks and feed a distinct home summary',
      (tester) async {
    final executor = openInMemoryExecutor();
    final dbs = await createCoreDatabases(executor);
    addTearDown(() async {
      await dbs.tasks.close();
      await dbs.habits.close();
    });
    await TaskRepository(dbs.tasks).add('Coexist task');

    await HabitRepository(dbs.habits).define('Read daily');
    await HabitRepository(dbs.habits).define(
      'Run weekly',
      schedule: HabitSchedule.weekly({1, 3, 5}),
    );

    await pumpLifeOSApp(tester, executor: executor);

    // Both domains are present on home; habits highlight today's items.
    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.byKey(const Key('summary-habits')), findsOneWidget);
    expect(find.text('Read daily'), findsOneWidget);
    expect(find.text('Streak: 0'), findsOneWidget);

    // Complete today's habit via the home highlight (direct action, SC-007).
    final highlight = find.textContaining('Read daily');
    await tester.tap(highlight);
    await tester.pumpAndSettle();
    expect(find.text('1 done today'), findsOneWidget);
    expect(find.text('1 outstanding'), findsOneWidget); // tasks untouched

    // Inside Habits, the weekly habit shows its schedule and a streak.
    await tester.tap(find.byKey(const Key('open-habits')));
    await tester.pumpAndSettle();
    expect(find.text('Mon · Wed · Fri'), findsOneWidget);
    expect(find.textContaining('Read daily'), findsWidgets);
    expect(find.textContaining('Streak 1'), findsWidgets);

    // Recording is strictly one entry per (habit, day): tapping today again
    // un-records (toggle), and history stays consistent.
    final readTile = find.ancestor(
      of: find.text('Read daily'),
      matching: find.byType(ListTile),
    );
    final todayCheckbox = find.descendant(
      of: readTile,
      matching: find.byType(Checkbox),
    );
    await tester.tap(todayCheckbox);
    await tester.pumpAndSettle();
    await tester.tap(todayCheckbox);
    await tester.pumpAndSettle();

    // Back home: habits reflect the un-record (done-today gone).
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(find.text('1 done today'), findsNothing);
    expect(find.text('1 outstanding'), findsOneWidget);
  });
}