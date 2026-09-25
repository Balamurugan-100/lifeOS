import 'package:lifeos_journal/lifeos_journal.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late JournalDatabase database;
  late JournalRepository repository;

  setUp(() async {
    database = JournalDatabase(openInMemoryExecutor());
    await database.customSelect('SELECT 1').get();
    repository = JournalRepository(database);
  });

  tearDown(() => database.close());

  group('Journal Repository Tests', () {
    test('records and retrieves daily reflections with mood scores', () async {
      final entry = await repository.recordEntry(
        id: 'entry_1',
        date: '2026-09-25',
        moodScore: 5,
        gratitude: 'Grateful for good health',
        reflection: 'Built amazing new features today.',
        tags: ['coding', 'health'],
      );

      expect(entry.moodScore, 5);
      expect(entry.mood, MoodType.amazing);
      expect(entry.tags, contains('coding'));

      final fetched = await repository.getEntryByDate('2026-09-25');
      expect(fetched, isNotNull);
      expect(fetched!.reflection, 'Built amazing new features today.');
    });

    test('updating existing entry for the same date modifies record in place',
        () async {
      await repository.recordEntry(
        id: 'entry_1',
        date: '2026-09-25',
        moodScore: 3,
        reflection: 'Initial thought',
      );

      final updated = await repository.recordEntry(
        id: 'entry_ignored_id',
        date: '2026-09-25',
        moodScore: 4,
        reflection: 'Updated evening reflection',
        gratitude: 'Family dinner',
      );

      expect(updated.moodScore, 4);
      expect(updated.reflection, 'Updated evening reflection');

      final all = await repository.getAllEntries();
      expect(all, hasLength(1));
    });

    test('calculates average mood score correctly', () async {
      await repository.recordEntry(
        id: '1',
        date: '2026-09-23',
        moodScore: 4,
        reflection: '',
      );
      await repository.recordEntry(
        id: '2',
        date: '2026-09-24',
        moodScore: 2,
        reflection: '',
      );
      await repository.recordEntry(
        id: '3',
        date: '2026-09-25',
        moodScore: 4,
        reflection: '',
      );

      final avg = await repository.getAverageMoodScore(limit: 7);
      expect(avg, closeTo(3.33, 0.05));
    });
  });
}
