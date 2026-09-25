import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late NoteDatabase database;
  late NotesRepository repository;

  setUp(() async {
    database = NoteDatabase(openInMemoryExecutor());
    await database.customSelect('SELECT 1').get();
    repository = NotesRepository(database);
  });

  tearDown(() => database.close());

  group('Notes Repository Tests', () {
    test('creates markdown notes, retrieves them and searches content', () async {
      final note = await repository.addNote(
        id: 'note_1',
        title: 'Project Architecture',
        content: '# LifeOS Architecture\n\n- Local first\n- Modular Drift DB\n- High performance',
        folder: 'Tech',
        tags: ['architecture', 'flutter'],
        isPinned: true,
      );

      expect(note.title, 'Project Architecture');
      expect(note.folder, 'Tech');
      expect(note.isPinned, isTrue);

      final searchResults = await repository.searchNotes('Modular Drift');
      expect(searchResults, hasLength(1));
      expect(searchResults.first.id, 'note_1');

      await repository.togglePin('note_1');
      final unpinned = await repository.getNoteById('note_1');
      expect(unpinned!.isPinned, isFalse);
    });

    test('deleting a note removes it from database', () async {
      await repository.addNote(
        id: 'note_temp',
        title: 'Temporary Scratchpad',
        content: 'Quick brainstorm thoughts',
      );

      final deleted = await repository.deleteNote('note_temp');
      expect(deleted, isTrue);

      final fetched = await repository.getNoteById('note_temp');
      expect(fetched, isNull);
    });
  });
}
