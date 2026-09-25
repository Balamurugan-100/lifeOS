import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/notes_screen.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('Notes screen lists notes, allows creating and filtering notes',
      (tester) async {
    final noteDb = NoteDatabase(openInMemoryExecutor());
    await noteDb.ensureTables();

    final repo = NotesRepository(noteDb);
    await repo.addNote(
      id: 'n1',
      title: 'Architecture Overview',
      content: '# System Architecture\nThis is a *markdown* doc.',
      folder: 'Work',
      tags: ['tech', 'design'],
      isPinned: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteDatabaseProvider.overrideWith((ref) async => noteDb),
        ],
        child: const MaterialApp(
          home: NotesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Notes & Docs'), findsOneWidget);
    expect(find.text('Architecture Overview'), findsOneWidget);
    expect(find.text('PINNED NOTES'), findsOneWidget);
    expect(find.text('Work'), findsWidgets);
    expect(find.text('#tech'), findsWidgets);

    // Open Note Editor via FAB
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New Note'), findsOneWidget);

    // Enter title and content
    await tester.enterText(
      find.widgetWithText(TextField, 'Note Title...'),
      'Product Launch Checklist',
    );
    await tester.enterText(
      find.byType(TextField).last,
      '## Launch Tasks\n- [ ] Deploy to production\n- [ ] Run verification tests',
    );
    await tester.pumpAndSettle();

    // Toggle Preview Mode
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Launch Tasks'), findsOneWidget);

    // Save note
    await tester.tap(find.byKey(const Key('saveNoteButton')));
    await tester.pumpAndSettle();

    // Verify back on notes list
    expect(find.text('Product Launch Checklist'), findsOneWidget);
  });
}
