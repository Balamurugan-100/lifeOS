import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// US1 independent test (T031): launch → empty state → navigate to the Tasks
/// and Habits module screens → back home.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch, empty state, navigate to Tasks and Habits, back',
      (tester) async {
    await pumpLifeOSApp(tester);

    expect(find.byKey(const Key('emptystate')), findsOneWidget);

    await tester.tap(find.byKey(const Key('openTasks')));
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('No tasks yet. Tap + to add your first one.'),
        findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptystate')), findsOneWidget);

    await tester.tap(find.byKey(const Key('openHabits')));
    await tester.pumpAndSettle();
    expect(find.text('Habits'), findsWidgets);
    expect(
        find.text('No habits yet. Tap + to build your first streak.'),
        findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptystate')), findsOneWidget);
  });
}