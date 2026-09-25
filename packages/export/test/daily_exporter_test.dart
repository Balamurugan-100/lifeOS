import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_export/lifeos_export.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_focus/lifeos_focus.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_journal/lifeos_journal.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

void main() {
  test('Daily Export generates comprehensive Markdown and JSON digests',
      () async {
    final taskDb = TaskDatabase(openInMemoryExecutor());
    final habitDb = HabitDatabase(openInMemoryExecutor());
    final financeDb = FinanceDatabase(openInMemoryExecutor());
    final journalDb = JournalDatabase(openInMemoryExecutor());
    final focusDb = FocusDatabase(openInMemoryExecutor());
    final noteDb = NoteDatabase(openInMemoryExecutor());

    await taskDb.ensureTables();
    await habitDb.ensureTables();
    await financeDb.ensureTables();
    await journalDb.ensureTables();
    await focusDb.ensureTables();
    await noteDb.ensureTables();

    final taskRepo = TaskRepository(taskDb);
    final habitRepo = HabitRepository(habitDb);
    final financeRepo = FinanceRepository(financeDb);
    final journalRepo = JournalRepository(journalDb);
    final focusRepo = FocusRepository(focusDb);
    final notesRepo = NotesRepository(noteDb);

    final today = DateTime.now();

    // Seed test data
    final task = await taskRepo.add(
      'Complete System Architecture Review',
      dueDate: today,
    );
    await taskRepo.toggle(task.id);

    await journalRepo.recordEntry(
      id: 'j1',
      date:
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
      moodScore: 5,
      gratitude: 'Grateful for deep focus and progress.',
      reflection: 'Shipped all core requirements smoothly.',
      tags: ['productivity', 'milestone'],
    );

    await focusRepo.recordSession(
      id: 'f1',
      durationSeconds: 3000,
      completedAt: today,
      mode: FocusMode.pomodoro,
      taskTitle: 'Coding & Architecture',
    );

    await notesRepo.addNote(
      id: 'n1',
      title: 'Sprint Retrospective',
      content: '# Sprint Summary\n- Delivered all features on time.',
      folder: 'Work',
      tags: ['retro'],
    );

    final exporter = LifeOSExporter(
      tasks: taskRepo,
      habits: habitRepo,
      finance: financeRepo,
      journal: journalRepo,
      focus: focusRepo,
      notes: notesRepo,
    );

    // 1. Verify Daily Markdown
    final md = await exporter.buildDailyMarkdown(today);
    expect(md, contains('LifeOS Daily Digest'));
    expect(md, contains('Daily Reflection & Mood'));
    expect(md, contains('Grateful for deep focus and progress.'));
    expect(md, contains('Shipped all core requirements smoothly.'));
    expect(md, contains('[x] Complete System Architecture Review'));
    expect(md, contains('50 mins'));
    expect(md, contains('Coding & Architecture'));
    expect(md, contains('Sprint Retrospective'));

    // 2. Verify file writing
    final tempDir = await Directory.systemTemp.createTemp('lifeos_test');
    final mdFile = File('${tempDir.path}/test_export.md');
    final jsonFile = File('${tempDir.path}/test_export.json');

    await exporter.writeDailyExportTo(today, mdFile, asMarkdown: true);
    expect(await mdFile.exists(), isTrue);
    expect(await mdFile.readAsString(), contains('LifeOS Daily Digest'));

    await exporter.writeDailyExportTo(today, jsonFile, asMarkdown: false);
    expect(await jsonFile.exists(), isTrue);
    final parsed = jsonDecode(await jsonFile.readAsString());
    expect(parsed['schemaVersion'], isNotNull);
    expect(parsed['domains'], isNotNull);

    await tempDir.delete(recursive: true);
  });
}
