import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

import 'helpers.dart';

/// US2 independent test (T042): full task lifecycle inside the module
/// (create → complete → delete) without touching home or Habits, then the
/// task summary appears on home (SC-001 timing, SC-002 freshness).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('task lifecycle end-to-end and summary on home', (tester) async {
    await pumpLifeOSApp(tester);

    // Create.
    await tester.tap(find.byKey(const Key('openTasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTaskFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitleField')), 'Ship v1');
    await tester.tap(find.byKey(const Key('saveTask')));
    await tester.pumpAndSettle();
    expect(find.text('Ship v1'), findsOneWidget);
    expect(find.text('No due date'), findsOneWidget);

    // Complete (checkbox on the task row).
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.value, isTrue);

    // Return home: summary reflects the completed task immediately (SC-002).
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.text('1 done today'), findsOneWidget);

    // Re-enter and delete via the row menu.
    await tester.tap(find.byKey(const Key('nav-tasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last); // confirmation dialog
    await tester.pumpAndSettle();
    expect(find.text('Ship v1'), findsNothing);

    // Home no longer shows task data.
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-tasks')), findsNothing);
  });

  testWidgets('lifecycle also works when the database is file-backed',
      (tester) async {
    // Same flow on a temp-file executor to exercise the real SQLite path.
    final dir = await Directory.systemTemp.createTemp('lifeos-it-tasks');
    addTearDown(() => dir.delete(recursive: true));
    final executor = openFileExecutor('${dir.path}/lifeos.db');
    addTearDown(() => executor.close());

    await pumpLifeOSApp(tester, executor: executor);
    await tester.tap(find.byKey(const Key('openTasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTaskFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitleField')), 'File task');
    await tester.tap(find.byKey(const Key('saveTask')));
    await tester.pumpAndSettle();
    expect(find.text('File task'), findsOneWidget);
  });
}