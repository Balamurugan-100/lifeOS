import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/bootstrap/registry.dart';
import 'package:lifeos_app/home/home_controller.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'helpers.dart';

/// US5 lifecycle (T061, FR-005, SC-003): disabling a module removes it from
/// home but keeps its data; re-enabling restores the summary exactly.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('disable → absent from home with data retained → re-enable',
      (tester) async {
    final executor = openInMemoryExecutor();
    final taskDb = TaskDatabase(executor);
    final habitDb = HabitDatabase(executor);
    addTearDown(() async {
      await taskDb.close();
      await habitDb.close();
    });
    await TaskRepository(taskDb).add('Task data A');
    await HabitRepository(habitDb).define('Habit data B');

    await pumpLifeOSApp(tester, executor: executor);
    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.byKey(const Key('summary-habits')), findsOneWidget);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(LifeOSApp)));

    // Disable Tasks.
    var registry = await container.read(moduleRegistryProvider.future);
    await registry.setEnabled('tasks', false);
    container.invalidate(moduleRegistryProvider);
    container.invalidate(summariesProvider);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-tasks')), findsNothing);
    expect(find.byKey(const Key('summary-habits')), findsOneWidget);

    // Data was retained (disable != delete).
    expect(await TaskRepository(taskDb).all(), hasLength(1));

    // Re-enable: the summary comes back exactly.
    registry = await container.read(moduleRegistryProvider.future);
    await registry.setEnabled('tasks', true);
    container.invalidate(moduleRegistryProvider);
    container.invalidate(summariesProvider);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.text('1 outstanding'), findsOneWidget);
    expect(find.byKey(const Key('summary-habits')), findsOneWidget);
  });

  testWidgets('settings screen toggles modules', (tester) async {
    final executor = openInMemoryExecutor();
    final taskDb = TaskDatabase(executor);
    final habitDb = HabitDatabase(executor);
    addTearDown(() async {
      await taskDb.close();
      await habitDb.close();
    });
    await TaskRepository(taskDb).add('Keep me');

    await pumpLifeOSApp(tester, executor: executor);
    await tester.tap(find.byKey(const Key('openSettings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('module-tasks')), findsOneWidget);
    expect(find.byKey(const Key('module-habits')), findsOneWidget);

    // Toggle Tasks off from the settings screen.
    await tester.tap(find.byKey(const Key('module-tasks')));
    await tester.pumpAndSettle();

    // Back on home, the Tasks summary is gone but data remains.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-tasks')), findsNothing);
    expect(await TaskRepository(taskDb).all(), hasLength(1));
  });
}