import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:test/test.dart';

void main() {
  DateTime utcNow() => DateTime.now().toUtc();

  Task buildTask({
    String title = 'Write report',
    TaskStatus status = TaskStatus.outstanding,
    DateTime? dueDate,
    int position = 0,
  }) {
    return Task(
      id: newId(),
      title: title,
      status: status,
      dueDate: dueDate,
      position: position,
      createdAt: utcNow(),
      updatedAt: utcNow(),
    );
  }

  group('Task model', () {
    test('generates a valid UUID v4 id via newId', () {
      final task = buildTask();
      expect(isValidId(task.id), isTrue);
    });

    group('title validation (data-model.md)', () {
      test('empty title throws ArgumentError', () {
        expect(() => buildTask(title: ''), throwsArgumentError);
      });

      test('whitespace-only title throws ArgumentError', () {
        expect(() => buildTask(title: '   '), throwsArgumentError);
      });

      test('title longer than 200 chars throws ArgumentError', () {
        expect(() => buildTask(title: 'x' * 201), throwsArgumentError);
      });

      test('title of exactly 200 chars is accepted', () {
        final task = buildTask(title: 'x' * 200);
        expect(task.title.length, 200);
      });

      test('title is stored trimmed', () {
        final task = buildTask(title: '  Buy oat milk  ');
        expect(task.title, 'Buy oat milk');
      });
    });

    test('negative position throws ArgumentError', () {
      expect(() => buildTask(position: -1), throwsArgumentError);
    });

    test('position of zero is valid', () {
      expect(buildTask(position: 0).position, 0);
    });

    group('status transitions', () {
      test('isCompleted is consistent with status', () {
        expect(buildTask(status: TaskStatus.outstanding).isCompleted, isFalse);
        expect(buildTask(status: TaskStatus.completed).isCompleted, isTrue);
      });

      test('constructing the same status repeatedly is stable (toggle idempotence)', () {
        final completed = buildTask(status: TaskStatus.completed);
        final again = Task(
          id: completed.id,
          title: completed.title,
          status: TaskStatus.completed,
          dueDate: completed.dueDate,
          position: completed.position,
          createdAt: completed.createdAt,
          updatedAt: completed.updatedAt,
        );
        expect(again.isCompleted, isTrue);
        expect(again.status, completed.status);
      });
    });

    group('isOverdue derivation', () {
      final today = DateTime(2026, 9, 22);

      test('due before today and outstanding is overdue', () {
        final task = buildTask(dueDate: DateTime(2026, 9, 21));
        expect(task.isOverdue(today), isTrue);
      });

      test('due today is not overdue', () {
        final task = buildTask(dueDate: DateTime(2026, 9, 22));
        expect(task.isOverdue(today), isFalse);
      });

      test('due after today is not overdue', () {
        final task = buildTask(dueDate: DateTime(2026, 9, 23));
        expect(task.isOverdue(today), isFalse);
      });

      test('undated task is never overdue', () {
        final task = buildTask(dueDate: null);
        expect(task.isOverdue(today), isFalse);
      });

      test('completed task with a past due date is not overdue', () {
        final task =
            buildTask(status: TaskStatus.completed, dueDate: DateTime(2026, 9, 21));
        expect(task.isOverdue(today), isFalse);
      });
    });

    group('priority, notes, category, and copyWith', () {
      test('supports priority levels and badges', () {
        final task = Task(
          id: newId(),
          title: 'Urgent Bug',
          status: TaskStatus.outstanding,
          dueDate: null,
          position: 0,
          priority: TaskPriority.urgent,
          notes: 'Detailed notes here',
          category: 'Work',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        expect(task.priority, TaskPriority.urgent);
        expect(task.priority.badge, 'P1');
        expect(task.priority.label, 'Urgent');
        expect(task.notes, 'Detailed notes here');
        expect(task.category, 'Work');
      });

      test('copyWith updates fields cleanly', () {
        final task = buildTask(title: 'Original');
        final updated = task.copyWith(
          title: 'Modified',
          priority: TaskPriority.high,
          notes: 'New notes',
          category: 'Personal',
        );

        expect(updated.title, 'Modified');
        expect(updated.priority, TaskPriority.high);
        expect(updated.notes, 'New notes');
        expect(updated.category, 'Personal');
      });
    });
  });
}