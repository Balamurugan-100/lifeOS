import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:test/test.dart';

void main() {
  // A fixed local calendar date so the summary tests are deterministic.
  final today = DateTime(2026, 9, 22);

  late TaskDatabase database;
  late TaskRepository repository;
  late TaskSummaryBuilder builder;

  setUp(() {
    database = TaskDatabase(openInMemoryExecutor());
    repository = TaskRepository(database);
    builder = TaskSummaryBuilder(repository);
  });

  tearDown(() => database.close());

  /// Rewrites a task's `updatedAt` directly so tests can place a completion
  /// on a day other than today (the summary reads `updatedAt.toLocal()`).
  Future<void> backdate(String id, DateTime updatedAt) async {
    await (database.update(database.tasks)
          ..where((t) => t.id.equals(id)))
        .write(TasksCompanion(updatedAt: Value(updatedAt.toUtc())));
  }

  group('TaskSummaryBuilder.build', () {
    test('computes outstanding/overdue/completedToday counts', () async {
      await repository.add('Overdue', dueDate: DateTime(2026, 9, 20));
      await repository.add('Due today', dueDate: DateTime(2026, 9, 22));
      await repository.add('Future', dueDate: DateTime(2026, 9, 30));
      await repository.add('Undated');

      final doneToday = await repository.add('Done today');
      await repository.setStatus(doneToday.id, TaskStatus.completed);

      final doneBefore = await repository.add('Done before');
      await repository.setStatus(doneBefore.id, TaskStatus.completed);
      await backdate(doneBefore.id, DateTime(2026, 9, 21, 12, 30));

      final summary = await builder.build(today: today);

      expect(summary.domainKey, 'tasks');
      expect(summary.displayName, 'Tasks');
      expect(summary.counts['outstanding'], 4);
      expect(summary.counts['overdue'], 1);
      expect(summary.counts['completedToday'], 1);
      expect(summary.refreshedAt.isUtc, isTrue);
    });

    test('prioritizes overdue tasks, then nearest due, capped at 3', () async {
      final future = await repository.add('Future', dueDate: DateTime(2026, 9, 25));
      final dueToday = await repository.add('Today', dueDate: DateTime(2026, 9, 22));
      final overdueLate =
          await repository.add('Overdue late', dueDate: DateTime(2026, 9, 21));
      final overdueEarly =
          await repository.add('Overdue early', dueDate: DateTime(2026, 9, 19));

      final summary = await builder.build(today: today);
      final highlighted = summary.highlighted;

      expect(highlighted, hasLength(3));
      expect(
        highlighted.map((h) => h.id).toList(),
        [overdueEarly.id, overdueLate.id, dueToday.id],
      );
      expect(highlighted.map((h) => h.kind).toList(),
          ['task.overdue', 'task.overdue', 'task.due']);
      expect(highlighted.map((h) => h.title).toList(),
          ['Overdue early', 'Overdue late', 'Today']);
      expect(highlighted[0].subtitle, 'Due 2026-09-19');
      expect(highlighted[1].subtitle, 'Due 2026-09-21');
      expect(highlighted[2].subtitle, 'Due 2026-09-22');
      expect(highlighted.every((h) => h.action == HighlightAction.complete),
          isTrue);
      expect(future.id, isNot(contains(highlighted.map((h) => h.id))));
    });

    test('caps highlighted items at 3', () async {
      for (var i = 0; i < 6; i++) {
        await repository.add('Task $i', dueDate: DateTime(2026, 9, 10 + i));
      }

      final summary = await builder.build(today: today);
      expect(summary.highlighted, hasLength(3));
    });

    test('undated outstanding tasks are never highlighted', () async {
      await repository.add('Undated');
      await repository.add('Also undated');

      final summary = await builder.build(today: today);
      expect(summary.counts['outstanding'], 2);
      expect(summary.highlighted, isEmpty);
    });

    test('completing a task moves it from outstanding into completedToday',
        () async {
      final task = await repository.add('Do it', dueDate: DateTime(2026, 9, 20));

      var summary = await builder.build(today: today);
      expect(summary.counts['outstanding'], 1);
      expect(summary.counts['completedToday'], 0);

      await repository.setStatus(task.id, TaskStatus.completed);

      summary = await builder.build(today: today);
      expect(summary.counts['outstanding'], 0);
      expect(summary.counts['completedToday'], 1);
      expect(summary.highlighted, isEmpty);
    });

    test('empty database yields an empty summary', () async {
      final summary = await builder.build(today: today);

      expect(summary.counts['outstanding'], 0);
      expect(summary.counts['overdue'], 0);
      expect(summary.counts['completedToday'], 0);
      expect(summary.highlighted, isEmpty);
      expect(summary.isEmpty, isTrue);
    });

    test('build defaults today to todayLocal when not provided', () async {
      await repository.add('Past due', dueDate: DateTime(2020, 1, 1));

      final summary = await builder.build();
      expect(summary.counts['overdue'], 1);
    });
  });
}