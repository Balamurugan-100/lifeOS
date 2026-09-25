import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/journal_screen.dart';
import 'package:lifeos_journal/lifeos_journal.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('Journal screen allows selecting mood, entering reflection and saving',
      (tester) async {
    final journalDb = JournalDatabase(openInMemoryExecutor());
    await journalDb.ensureTables();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalDatabaseProvider.overrideWith((ref) async => journalDb),
        ],
        child: const MaterialApp(
          home: JournalScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Journal & Mood'), findsOneWidget);
    expect(find.text("Today's Check-in"), findsOneWidget);
    expect(find.text('How are you feeling today?'), findsOneWidget);

    // Tap mood 5 (Amazing)
    await tester.tap(find.byKey(const Key('mood_5')));
    await tester.pumpAndSettle();

    // Enter reflection text
    await tester.enterText(
      find.widgetWithText(TextField, 'Daily Reflection & Thoughts'),
      'Feeling great today after completing our major milestones!',
    );
    await tester.pumpAndSettle();

    // Tap save reflection
    await tester.tap(find.byKey(const Key('saveJournalButton')));
    await tester.pumpAndSettle();

    expect(find.text('✨ Daily reflection saved!'), findsOneWidget);
    expect(find.text('Feeling great today after completing our major milestones!'),
        findsOneWidget);
  });
}
