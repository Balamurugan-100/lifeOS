import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:test/test.dart';

void main() {
  late TaskDatabase database;
  late TaskRepository repository;

  setUp(() {
    database = TaskDatabase(openInMemoryExecutor());
    repository = TaskRepository(database);
  });

  tearDown(() => database.close());

  group('add', () {
    test('assigns auto-incrementing position and trims the title', () async {
      final first = await repository.add('  Buy oat milk  ');
      final second = await repository.add('File taxes');

      expect(first.title, 'Buy oat milk');
      expect(first.position, 0);
      expect(second.title, 'File taxes');
      expect(second.position, 1);
    });

    test('rejects an invalid title', () async {
      expect(() => repository.add(''), throwsArgumentError);
      expect(() => repository.add('   '), throwsArgumentError);
      expect(() => repository.add('x' * 201), throwsArgumentError);
    });

    test('accepts a due date and clears an empty (epoch) due date to null',
        () async {
      final dated = await repository.add('Dated', dueDate: DateTime(2026, 10, 1));
      expect(dated.dueDate, DateTime(2026, 10, 1));

      final empty =
          await repository.add('Empty', dueDate: DateTime.fromMillisecondsSinceEpoch(0));
      expect(empty.dueDate, isNull);
    });

    test('records audit fields as UTC on insert', () async {
      final task = await repository.add('Audit me');

      expect(task.createdAt.isUtc, isTrue);
      expect(task.updatedAt.isUtc, isTrue);
      expect(task.createdAt, task.updatedAt);
    });

    test('defaults a new task to outstanding', () async {
      final task = await repository.add('Fresh');
      expect(task.status, TaskStatus.outstanding);
      expect(task.isCompleted, isFalse);
    });
  });

  group('byId', () {
    test('returns the stored task', () async {
      final task = await repository.add('Find me');
      final fetched = await repository.byId(task.id);

      expect(fetched, isNotNull);
      expect(fetched!.id, task.id);
      expect(fetched.title, 'Find me');
    });

    test('returns null for an unknown id', () async {
      expect(await repository.byId('does-not-exist'), isNull);
    });
  });

  group('updateTitle', () {
    test('updates the title and refreshes updatedAt', () async {
      final task = await repository.add('Old title');
      final originalUpdatedAt = task.updatedAt;

      await repository.updateTitle(task.id, '   New title   ');

      final fetched = (await repository.byId(task.id))!;
      expect(fetched.title, 'New title');
      expect(fetched.updatedAt.isAfter(originalUpdatedAt), isTrue);
    });

    test('rejects an invalid title', () async {
      final task = await repository.add('Keep me');
      expect(() => repository.updateTitle(task.id, ''), throwsArgumentError);
      expect(() => repository.updateTitle(task.id, '   '), throwsArgumentError);
    });
  });

  group('setDueDate', () {
    test('sets a due date', () async {
      final task = await repository.add('Plan');
      final due = DateTime(2026, 12, 24);

      await repository.setDueDate(task.id, due);
      expect((await repository.byId(task.id))!.dueDate, due);
    });

    test('clears a due date back to null', () async {
      final task = await repository.add('Unplan');
      await repository.setDueDate(task.id, DateTime(2026, 12, 24));

      await repository.setDueDate(task.id, null);
      expect((await repository.byId(task.id))!.dueDate, isNull);
    });

    test('treats an empty (epoch) due date as null', () async {
      final task = await repository.add('Empty again');
      await repository.setDueDate(task.id, DateTime(2026, 12, 24));

      await repository
          .setDueDate(task.id, DateTime.fromMillisecondsSinceEpoch(0));
      expect((await repository.byId(task.id))!.dueDate, isNull);
    });
  });

  group('setStatus', () {
    test('changes status and refreshes updatedAt', () async {
      final task = await repository.add('Do this');
      final originalUpdatedAt = task.updatedAt;

      await repository.setStatus(task.id, TaskStatus.completed);

      final completed = (await repository.byId(task.id))!;
      expect(completed.status, TaskStatus.completed);
      expect(completed.isCompleted, isTrue);
      expect(completed.updatedAt.isAfter(originalUpdatedAt), isTrue);
    });

    test('is idempotent: second identical call writes nothing', () async {
      final task = await repository.add('Idempotent');

      await repository.setStatus(task.id, TaskStatus.completed);
      final afterFirst = (await repository.byId(task.id))!;
      final updatedAtAfterFirst = afterFirst.updatedAt;

      await repository.setStatus(task.id, TaskStatus.completed);
      final afterSecond = (await repository.byId(task.id))!;

      expect(afterSecond.status, TaskStatus.completed);
      expect(afterSecond.updatedAt, updatedAtAfterFirst);
    });
  });

  group('toggle', () {
    test('flips outstanding <-> completed and returns the refetched task',
        () async {
      final task = await repository.add('Toggle me');
      expect(task.isCompleted, isFalse);

      final completed = await repository.toggle(task.id);
      expect(completed.status, TaskStatus.completed);
      expect(completed.id, task.id);

      final reopened = await repository.toggle(task.id);
      expect(reopened.status, TaskStatus.outstanding);
    });
  });

  group('delete', () {
    test('removes the task from the list', () async {
      final task = await repository.add('Doomed');
      expect(await repository.all(), hasLength(1));

      await repository.delete(task.id);

      expect(await repository.byId(task.id), isNull);
      expect(await repository.all(), isEmpty);
    });
  });

  group('reorder', () {
    test('rewrites positions 0..n-1 in the given order', () async {
      final a = await repository.add('A');
      final b = await repository.add('B');
      final c = await repository.add('C');

      await repository.reorder([c.id, a.id, b.id]);

      final tasks = await repository.all();
      expect(tasks.map((t) => t.id).toList(), [c.id, a.id, b.id]);
      expect(tasks.map((t) => t.position).toList(), [0, 1, 2]);
    });

    test('ignores ids that are not in the database', () async {
      final a = await repository.add('A');
      final b = await repository.add('B');
      final c = await repository.add('C');

      await repository.reorder([b.id, 'missing-id', c.id, a.id]);

      final tasks = await repository.all();
      expect(tasks.map((t) => t.id).toList(), [b.id, c.id, a.id]);
      expect(tasks.map((t) => t.position).toList(), [0, 1, 2]);
    });
  });

  group('all', () {
    test('orders by position asc with createdAt as tie-break', () async {
      final a = await repository.add('A');
      final b = await repository.add('B');
      final c = await repository.add('C');

      await repository.reorder([a.id, c.id]); // b keeps its position (1)

      final tasks = await repository.all();
      // a -> 0, c -> 1, b -> 1 (older createdAt wins the tie-break).
      expect(tasks.map((t) => t.id).toList(), [a.id, b.id, c.id]);
    });

    test('returns tasks in insertion order when positions are unique', () async {
      final a = await repository.add('A');
      final b = await repository.add('B');
      final c = await repository.add('C');

      final tasks = await repository.all();
      expect(tasks.map((t) => t.id).toList(), [a.id, b.id, c.id]);
    });
  });

  group('priority, notes, category, and updateTask', () {
    test('add stores priority, notes, and category', () async {
      final task = await repository.add(
        'Feature work',
        priority: TaskPriority.urgent,
        notes: 'Needs urgent fix',
        category: 'Work',
      );

      expect(task.priority, TaskPriority.urgent);
      expect(task.notes, 'Needs urgent fix');
      expect(task.category, 'Work');

      final fetched = (await repository.byId(task.id))!;
      expect(fetched.priority, TaskPriority.urgent);
      expect(fetched.notes, 'Needs urgent fix');
      expect(fetched.category, 'Work');
    });

    test('updateTask modifies fields and refreshes updatedAt', () async {
      final task = await repository.add('Initial task');
      await repository.updateTask(
        task.id,
        title: 'Updated title',
        priority: TaskPriority.high,
        notes: 'Added notes',
        category: 'Personal',
      );

      final fetched = (await repository.byId(task.id))!;
      expect(fetched.title, 'Updated title');
      expect(fetched.priority, TaskPriority.high);
      expect(fetched.notes, 'Added notes');
      expect(fetched.category, 'Personal');
    });

    test('updateTask can clear notes, category, and due date', () async {
      final task = await repository.add(
        'Task to clear',
        dueDate: DateTime(2026, 10, 1),
        notes: 'Some notes',
        category: 'Work',
      );

      await repository.updateTask(
        task.id,
        clearDueDate: true,
        clearNotes: true,
        clearCategory: true,
      );

      final fetched = (await repository.byId(task.id))!;
      expect(fetched.dueDate, isNull);
      expect(fetched.notes, isNull);
      expect(fetched.category, isNull);
    });

    test('ensureTables adds missing columns to existing older tables', () async {
      // Simulate an old table created without priority/notes/category
      final rawExecutor = openInMemoryExecutor();
      final customDb = TaskDatabase(rawExecutor);
      // Run custom raw table create without new columns
      await customDb.customStatement('''
        CREATE TABLE IF NOT EXISTS old_tasks (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          status TEXT NOT NULL,
          due_date INTEGER,
          position INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      // Running ensureTables on tasks database migrates columns if table was created in old schema
      await customDb.ensureTables();
      final repo = TaskRepository(customDb);
      final added = await repo.add(
        'Migrated Task',
        priority: TaskPriority.urgent,
        notes: 'Seamless migration',
        category: 'Work',
      );
      expect(added.priority, TaskPriority.urgent);
      expect(added.notes, 'Seamless migration');
      expect(added.category, 'Work');
      await customDb.close();
    });
  });
}