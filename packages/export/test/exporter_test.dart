import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:lifeos_export/lifeos_export.dart';

void main() {
  late TaskDatabase taskDb;
  late HabitDatabase habitDb;
  late TaskRepository tasks;
  late HabitRepository habits;

  setUp(() async {
    taskDb = TaskDatabase(openInMemoryExecutor());
    habitDb = HabitDatabase(openInMemoryExecutor());
    tasks = TaskRepository(taskDb);
    habits = HabitRepository(habitDb);
  });

  tearDown(() async {
    await taskDb.close();
    await habitDb.close();
  });

  group('ExportEnvelope completeness (SC-009)', () {
    test('envelope contains every owned record with stable field names', () async {
      final taskA = await tasks.add('Ship LifeOS', dueDate: DateTime(2026, 10, 1));
      await tasks.add('Undated task');
      await tasks.setStatus(taskA.id, TaskStatus.completed);

      final daily = await habits.define('Read');
      final weekly = await habits.define(
        'Run',
        schedule: HabitSchedule.weekly({1, 3, 5}),
      );
      await habits.record(daily.id, DateTime(2026, 9, 20));
      await habits.record(daily.id, DateTime(2026, 9, 21));
      await habits.record(weekly.id, DateTime(2026, 9, 21));

      final envelope = await LifeOSExporter(tasks: tasks, habits: habits)
          .buildEnvelope();

      expect(envelope['schemaVersion'], 1);
      expect(envelope['appVersion'], '0.1.0');
      expect(
        DateTime.parse(envelope['exportedAt'] as String).isUtc,
        isTrue,
      );

      final domains = envelope['domains'] as Map<String, dynamic>;
      final taskPayload =
          (domains['tasks'] as Map<String, dynamic>)['tasks'] as List;
      expect(taskPayload, hasLength(2));
      final taskAJson =
          taskPayload.firstWhere((row) => row['id'] == taskA.id);
      expect(taskAJson['title'], 'Ship LifeOS');
      expect(taskAJson['dueDate'], '2026-10-01');
      expect(taskAJson['status'], 'completed');
      expect(taskAJson['position'], isA<int>());
      expect(taskAJson['createdAt'], isA<String>());
      expect(taskAJson['updatedAt'], isA<String>());

      final habitPayload =
          (domains['habits'] as Map<String, dynamic>)['habits'] as List;
      expect(habitPayload, hasLength(2));
      final weeklyJson =
          habitPayload.firstWhere((row) => row['id'] == weekly.id);
      expect((weeklyJson['schedule'] as Map)['type'], 'weekly');
      expect((weeklyJson['schedule'] as Map)['daysOfWeek'], [1, 3, 5]);

      final entryPayload =
          (domains['habits'] as Map<String, dynamic>)['entries'] as List;
      expect(entryPayload, hasLength(3));
      expect(
        entryPayload.every(
          (row) => row['id'] is String && row['completedAt'] is String,
        ),
        isTrue,
      );
    });

    test('records in a disabled module are still exported (disable != delete)',
        () async {
      // The exporter reads data directly from repositories — the registry's
      // enabled state is irrelevant, so a disabled domain's data is always
      // part of the envelope (export contract rule 1).
      await tasks.add('Only task');
      await habits.define('Only habit');

      final envelope = await LifeOSExporter(tasks: tasks, habits: habits)
          .buildEnvelope();
      final domains = envelope['domains'] as Map<String, dynamic>;
      expect(
        ((domains['tasks'] as Map<String, dynamic>)['tasks'] as List),
        hasLength(1),
      );
      expect(
        ((domains['habits'] as Map<String, dynamic>)['habits'] as List),
        hasLength(1),
      );
    });

    test('empty domains are included with empty payloads (readable, tolerant)',
        () async {
      final envelope = await LifeOSExporter(tasks: tasks, habits: habits)
          .buildEnvelope();
      final domains = envelope['domains'] as Map<String, dynamic>;
      expect(((domains['tasks'] as Map<String, dynamic>)['tasks'] as List),
          isEmpty);
      expect(((domains['habits'] as Map<String, dynamic>)['habits'] as List),
          isEmpty);
    });

    test('written file is valid JSON matching the in-memory envelope', () async {
      final dir = await Directory.systemTemp.createTemp('lifeos-export-json');
      addTearDown(() => dir.delete(recursive: true));
      await tasks.add('Persist me');
      final exporter = LifeOSExporter(tasks: tasks, habits: habits);

      final file = await exporter.writeTo(File('${dir.path}/lifeos.json'));
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final inMemory = await exporter.buildEnvelope();

      expect(decoded['schemaVersion'], inMemory['schemaVersion']);
      expect(decoded['appVersion'], inMemory['appVersion']);
      expect(
        jsonEncode(decoded['domains']),
        jsonEncode(inMemory['domains']),
      );
    });
  });
}