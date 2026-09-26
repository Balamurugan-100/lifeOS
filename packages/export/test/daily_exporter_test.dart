import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_export/lifeos_export.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

/// The daily digest is the app's "one file to look at" artifact. It must cover
/// the three surviving domains and degrade gracefully when each is empty.
void main() {
  late TaskDatabase taskDb;
  late HabitDatabase habitDb;
  late FinanceDatabase financeDb;
  late TaskRepository tasks;
  late HabitRepository habits;
  late FinanceRepository finance;
  late TimeRepository time;

  /// A fixed local day so the digest's date-scoped sections are deterministic.
  final day = DateTime(2026, 9, 22);

  setUp(() async {
    taskDb = TaskDatabase(openInMemoryExecutor());
    habitDb = HabitDatabase(openInMemoryExecutor());
    financeDb = FinanceDatabase(openInMemoryExecutor());
    await taskDb.ensureTables();
    await habitDb.ensureTables();
    await financeDb.ensureTables();

    tasks = TaskRepository(taskDb);
    habits = HabitRepository(habitDb);
    finance = FinanceRepository(financeDb);
    time = TimeRepository(taskDb);
  });

  tearDown(() async {
    await taskDb.close();
    await habitDb.close();
    await financeDb.close();
  });

  LifeOSExporter exporter({bool withFinance = true}) => LifeOSExporter(
        tasks: tasks,
        habits: habits,
        time: time,
        finance: withFinance ? finance : null,
      );

  group('buildDailyMarkdown', () {
    test('renders all four sections for a day with data', () async {
      final habit = await habits.define('Read');
      await habits.record(habit.id, day);

      final task = await tasks.add('Complete System Architecture Review');
      await tasks.setStatus(task.id, TaskStatus.completed);

      // A closed 40-minute session on the task, tagged as a pomodoro.
      final session = await time.startSession(task.id, isPomodoro: true);
      final start = day.add(const Duration(hours: 9)).toUtc();
      await (taskDb.update(taskDb.timeSessions)
            ..where((s) => s.id.equals(session.id)))
          .write(TimeSessionsCompanion(
            startedAt: Value(start),
            endedAt: Value(start.add(const Duration(minutes: 40))),
            durationSeconds: const Value(2400),
          ));

      final account = await finance.addAccount(
        name: 'Wallet',
        type: AccountType.cash,
      );
      await finance.addTransaction(
        accountId: account.id,
        type: TransactionType.expense,
        amount: 125.5,
        categoryId: 'food',
        note: 'Lunch',
        date: day,
      );

      final md = await exporter().buildDailyMarkdown(day);

      expect(md, contains('# LifeOS Daily Digest - 2026-09-22'));
      expect(md, contains('## Habits Completed (1)'));
      expect(md, contains('- [x] Read'));
      expect(md, contains('## Tasks Completed (1)'));
      expect(md, contains('- [x] Complete System Architecture Review'));
      expect(md, contains('## Time Tracked (40 min)'));
      expect(
        md,
        contains(
          '- **Complete System Architecture Review** \u2014 40 min (pomodoro)',
        ),
      );
      expect(md, contains('## Finance Activity (1 txs)'));
      expect(md, contains('Lunch'));
      expect(md.trimRight(), endsWith('_Exported from LifeOS_'));
    });

    test('empty sections state that there is nothing rather than vanishing',
        () async {
      final md = await exporter().buildDailyMarkdown(day);

      expect(md, contains('## Habits Completed (0)'));
      expect(md, contains('_No habits recorded on this day._'));
      expect(md, contains('## Tasks Completed (0)'));
      expect(md, contains('_No tasks marked complete._'));
      expect(md, contains('## Time Tracked (0 min)'));
      expect(md, contains('_No tracked time on this day._'));
      expect(md, contains('## Finance Activity (0 txs)'));
      expect(md, contains('_No transactions on this day._'));
    });

    test('time tracked only counts sessions started on the target day',
        () async {
      final task = await tasks.add('Work');
      final yesterday = day.subtract(const Duration(days: 1));

      Future<void> seed(DateTime when, int seconds) async {
        final session = await time.startSession(task.id);
        await time.stopSession(session.id);
        await (taskDb.update(taskDb.timeSessions)
              ..where((s) => s.id.equals(session.id)))
            .write(TimeSessionsCompanion(
              startedAt: Value(when.toUtc()),
              endedAt: Value(when.toUtc().add(Duration(seconds: seconds))),
              durationSeconds: Value(seconds),
            ));
      }

      await seed(yesterday, 3600);
      await seed(day, 1800);

      final md = await exporter(withFinance: false).buildDailyMarkdown(day);

      expect(md, contains('## Time Tracked (30 min)'));
      expect(md, isNot(contains('60 min')));
    });

    test('a session for a task that no longer exists still reports its time',
        () async {
      final task = await tasks.add('Doomed');
      final session = await time.startSession(task.id);
      final start = day.add(const Duration(hours: 8)).toUtc();
      await (taskDb.update(taskDb.timeSessions)
            ..where((s) => s.id.equals(session.id)))
          .write(TimeSessionsCompanion(
            startedAt: Value(start),
            endedAt: Value(start.add(const Duration(minutes: 20))),
            durationSeconds: const Value(1200),
          ));
      await tasks.delete(task.id);

      final md = await exporter(withFinance: false).buildDailyMarkdown(day);

      expect(md, contains('## Time Tracked (20 min)'));
      expect(md, contains('**Unlinked session** \u2014 20 min'));
    });

    test('the finance section is absent when no finance repository is wired',
        () async {
      final md = await exporter(withFinance: false).buildDailyMarkdown(day);

      expect(md, isNot(contains('## Finance Activity')));
    });
  });

  group('writeDailyExportTo', () {
    test('writes Markdown by default and JSON on request', () async {
      await tasks.add('Persisted task');
      final dir = await Directory.systemTemp.createTemp('lifeos-daily');
      addTearDown(() => dir.delete(recursive: true));

      final mdFile = File('${dir.path}/digest.md');
      await exporter().writeDailyExportTo(day, mdFile);
      expect(mdFile.readAsStringSync(), contains('# LifeOS Daily Digest'));

      final jsonFile = File('${dir.path}/digest.json');
      await exporter().writeDailyExportTo(day, jsonFile, asMarkdown: false);
      final body = jsonFile.readAsStringSync();
      expect(body, contains('"schemaVersion": 1'));
      expect(body, contains('Persisted task'));
    });

    test('creates missing parent directories', () async {
      final dir = await Directory.systemTemp.createTemp('lifeos-daily-nested');
      addTearDown(() => dir.delete(recursive: true));

      final target = File('${dir.path}/a/b/c/digest.md');
      await exporter().writeDailyExportTo(day, target);

      expect(target.existsSync(), isTrue);
    });

    test('wraps write failures in ExportException', () async {
      final dir = await Directory.systemTemp.createTemp('lifeos-daily-fail');
      addTearDown(() => dir.delete(recursive: true));
      final asDirectory = File(dir.path);

      expect(
        () => exporter().writeDailyExportTo(day, asDirectory),
        throwsA(isA<ExportException>()),
      );
    });
  });
}
