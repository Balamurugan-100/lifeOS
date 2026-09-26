import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// US4 offline operation (T056): every core flow (home, Tasks, Habits) works
/// with no network available. LifeOS makes no network calls at all — the
/// flows below run headless exactly as they would in airplane mode. The
/// static half of FR-008 (no network packages, no INTERNET permission) lives
/// in `test/offline_audit_test.dart`, because it reads the repo's own files,
/// which do not exist on the device these tests run on.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all core flows work offline (SC-004)', (tester) async {
    await pumpLifeOSApp(tester);

    // Home.
    expect(find.byKey(const Key('emptystate')), findsOneWidget);

    // Tasks.
    await tester.tap(find.byKey(const Key('openTasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTaskFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitleField')), 'Offline');
    await tester.tap(find.byKey(const Key('saveTask')));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();

    // Habits.
    await tester.tap(find.byKey(const Key('openHabits')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No habits yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
  });
}