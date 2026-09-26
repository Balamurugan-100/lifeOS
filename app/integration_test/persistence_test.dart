import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'helpers.dart';

/// US4 persistence (T057): data created offline survives a full app restart
/// with zero loss (FR-009, SC-005). Simulated as two sessions over the same
/// SQLite file: session 1 writes, the executor is closed (restart), session
/// 2 reopens the file and reads everything back unchanged.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('data survives a restart on the same database file (FR-009, SC-005)',
      () async {
    final dir = await Directory.systemTemp.createTemp('lifeos-persist');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/lifeos.db';

    // ---- Session 1: create data offline ----
    final session1 = openFileExecutor(path);
    final dbs = await createCoreDatabases(session1);
    final tasks = TaskRepository(dbs.tasks);
    final habits = HabitRepository(dbs.habits);

    final task = await tasks.add('Persisted task',
        dueDate: DateTime(2026, 10, 5));
    final habit =
        await habits.define('Persisted habit', schedule: HabitSchedule.weekly({1, 4}));
    await habits.record(habit.id, DateTime(2026, 9, 21));
    await habits.record(habit.id, DateTime(2026, 9, 18));

    await dbs.tasks.close();
    await dbs.habits.close();
    await closeExecutor(session1);

    // ---- Session 2: full app restart ----
    final session2 = openFileExecutor(path);
    final dbs2 = await createCoreDatabases(session2);
    final tasks2 = TaskRepository(dbs2.tasks);
    final habits2 = HabitRepository(dbs2.habits);

    final reloadedTasks = await tasks2.all();
    expect(reloadedTasks, hasLength(1));
    expect(reloadedTasks.single.id, task.id);
    expect(reloadedTasks.single.title, 'Persisted task');
    expect(isSameDay(reloadedTasks.single.dueDate!, DateTime(2026, 10, 5)),
        isTrue);

    final reloadedHabits = await habits2.all();
    expect(reloadedHabits, hasLength(1));
    expect(reloadedHabits.single.name, 'Persisted habit');
    expect(reloadedHabits.single.schedule.daysOfWeek, {1, 4});

    final entries = await habits2.entryDates(habit.id);
    expect(entries, hasLength(2));
    expect(entries.any((d) => isSameDay(d, DateTime(2026, 9, 21))), isTrue);
    expect(entries.any((d) => isSameDay(d, DateTime(2026, 9, 18))), isTrue);

    await dbs2.tasks.close();
    await dbs2.habits.close();
    await closeExecutor(session2);
  });
}