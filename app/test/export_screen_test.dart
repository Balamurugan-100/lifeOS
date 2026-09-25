import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/export_screen.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

void main() {
  testWidgets('Export screen displays Daily Digest and Full Backup options',
      (tester) async {
    final taskDb = TaskDatabase(openInMemoryExecutor());
    final habitDb = HabitDatabase(openInMemoryExecutor());
    final noteDb = NoteDatabase(openInMemoryExecutor());
    await taskDb.ensureTables();
    await habitDb.ensureTables();
    await noteDb.ensureTables();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDatabaseProvider.overrideWith((ref) async => taskDb),
          habitDatabaseProvider.overrideWith((ref) async => habitDb),
          noteDatabaseProvider.overrideWith((ref) async => noteDb),
        ],
        child: const MaterialApp(
          home: ExportScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Export & Data Privacy'), findsOneWidget);
    expect(find.text('Daily Digest Export'), findsOneWidget);
    expect(find.text('Full LifeOS Backup'), findsOneWidget);
    expect(find.text('Markdown (.md)'), findsOneWidget);
    expect(find.text('JSON (.json)'), findsOneWidget);
    expect(find.byKey(const Key('exportDailyButton')), findsOneWidget);
    expect(find.byKey(const Key('exportNow')), findsOneWidget);

    // Switch to JSON format for Daily
    await tester.tap(find.text('JSON (.json)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('JSON'), findsWidgets);
  });
}
