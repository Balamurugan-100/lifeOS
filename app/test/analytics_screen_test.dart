import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/analytics_screen.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_focus/lifeos_focus.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_journal/lifeos_journal.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

void main() {
  testWidgets('Analytics screen renders habit heatmap, cashflow, and velocity metrics',
      (tester) async {
    final habitDb = HabitDatabase(openInMemoryExecutor());
    await habitDb.ensureTables();
    final financeDb = FinanceDatabase(openInMemoryExecutor());
    await financeDb.ensureTables();
    final taskDb = TaskDatabase(openInMemoryExecutor());
    await taskDb.ensureTables();
    final focusDb = FocusDatabase(openInMemoryExecutor());
    await focusDb.ensureTables();
    final journalDb = JournalDatabase(openInMemoryExecutor());
    await journalDb.ensureTables();

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitDatabaseProvider.overrideWith((ref) async => habitDb),
          financeDatabaseProvider.overrideWith((ref) async => financeDb),
          taskDatabaseProvider.overrideWith((ref) async => taskDb),
          focusDatabaseProvider.overrideWith((ref) async => focusDb),
          journalDatabaseProvider.overrideWith((ref) async => journalDb),
        ],
        child: const MaterialApp(
          home: AnalyticsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Interactive Analytics & Trends'), findsOneWidget);
    expect(find.text('Habit Consistency Heatmap'), findsOneWidget);
    expect(find.text('Financial Health & Cashflow'), findsOneWidget);
    expect(find.text('Productivity & Focus Velocity'), findsOneWidget);
    expect(find.text('Habit & Mood Correlation'), findsOneWidget);
  });
}
