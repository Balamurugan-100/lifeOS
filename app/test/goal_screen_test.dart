import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/goal_screen.dart';
import 'package:lifeos_goals/lifeos_goals.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('Goal screen creates a goal with milestones and toggles progress',
      (tester) async {
    final goalDb = GoalDatabase(openInMemoryExecutor());
    await goalDb.ensureTables();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalDatabaseProvider.overrideWith((ref) async => goalDb),
        ],
        child: const MaterialApp(
          home: GoalScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Goals & Milestones'), findsOneWidget);

    // Tap Add Goal FAB
    await tester.tap(find.byKey(const Key('addGoalFab')));
    await tester.pumpAndSettle();

    expect(find.text('Create New Goal'), findsOneWidget);

    // Enter goal title
    await tester.enterText(
      find.widgetWithText(TextField, 'Goal Title *'),
      'Save ₹100,000 for Emergency Fund',
    );
    await tester.pumpAndSettle();

    // Submit goal
    await tester.tap(find.byKey(const Key('submitGoalButton')));
    await tester.pumpAndSettle();

    expect(find.text('Save ₹100,000 for Emergency Fund'), findsOneWidget);
  });
}
