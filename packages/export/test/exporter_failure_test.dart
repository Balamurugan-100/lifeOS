import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:lifeos_export/lifeos_export.dart';

void main() {
  test('export failure leaves data unmodified and retry succeeds (T070)',
      () async {
    final taskDb = TaskDatabase(openInMemoryExecutor());
    final habitDb = HabitDatabase(openInMemoryExecutor());
    addTearDown(() async {
      await taskDb.close();
      await habitDb.close();
    });
    final tasks = TaskRepository(taskDb);
    final habits = HabitRepository(habitDb);
    final time = TimeRepository(taskDb);

    final task = await tasks.add('Keep me safe');
    await habits.define('Keep me too');
    final exporter =
        LifeOSExporter(tasks: tasks, habits: habits, time: time);

    // Storage-full style failure: the target path is an existing directory,
    // so writing a file "into" it raises a FileSystemException.
    final dir = await Directory.systemTemp.createTemp('lifeos-export-fail');
    addTearDown(() => dir.delete(recursive: true));
    final unwritable = File(dir.path); // a directory, not a file

    expect(
      () => exporter.writeTo(unwritable),
      throwsA(isA<ExportException>()),
    );

    // Data was never modified.
    final after = await tasks.all();
    expect(after.single.id, task.id);
    expect(after.single.title, 'Keep me safe');
    expect((await habits.all()), hasLength(1));

    // Retry against a writable target succeeds and contains the data.
    final okTarget = File('${dir.path}/retry.json');
    await exporter.writeTo(okTarget);
    expect(okTarget.existsSync(), isTrue);
    expect(okTarget.readAsStringSync(), contains('"Keep me safe"'));
  });
}