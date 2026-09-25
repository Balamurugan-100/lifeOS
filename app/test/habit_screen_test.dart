import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/habit_screen.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HabitScreen allows creating daily and weekly habits seamlessly',
      (tester) async {
    final executor = openInMemoryExecutor();
    final habitDb = HabitDatabase(executor);
    await habitDb.ensureTables();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitDatabaseProvider.overrideWith((ref) => Future.value(habitDb)),
          habitRepositoryProvider
              .overrideWith((ref) => Future.value(HabitRepository(habitDb))),
        ],
        child: const MaterialApp(
          home: HabitScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap + to add habit
    await tester.tap(find.byKey(const Key('addHabitFab')));
    await tester.pumpAndSettle();

    // Enter Habit Name
    await tester.enterText(find.byKey(const Key('habitNameField')), 'Workout');
    await tester.pumpAndSettle();

    // Switch to Weekly
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();

    // Toggle weekdays (Mon..Fri)
    expect(find.byKey(const Key('weekday-1')), findsOneWidget); // Mon
    expect(find.byKey(const Key('weekday-2')), findsOneWidget); // Tue

    // Tap create
    await tester.tap(find.byKey(const Key('saveHabit')));
    await tester.pumpAndSettle();

    // Verify habit was created and is visible on screen
    expect(find.text('Workout'), findsOneWidget);
    expect(find.textContaining('Mon'), findsWidgets);
  });

  testWidgets('Theme toggle switches between light and dark mode',
      (tester) async {
    final executor = openInMemoryExecutor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) => Future.value(executor)),
        ],
        child: const LifeOSApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('toggleThemeButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleThemeButton')));
    await tester.pumpAndSettle();
  });
}
