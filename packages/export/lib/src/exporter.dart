import 'dart:convert';
import 'dart:io';

import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

/// Raised when an export cannot be produced or written (T070 edge case).
///
/// Export is strictly read-only: a failure never modifies user data, and the
/// caller can simply retry.
class ExportException implements Exception {
  ExportException(this.message);

  final String message;

  @override
  String toString() => 'ExportException: $message';
}

/// Builds the portable one-tap JSON export envelope
/// (contracts/export-format-contract.md, FR-013, SC-009).
///
/// Shape: `{schemaVersion, exportedAt, appVersion, domains: {tasks: {tasks:
/// [...]}, habits: {habits: [...], entries: [...]}}}`. Additive fields and
/// new domains are tolerated by consumers; `schemaVersion` bumps only for
/// breaking changes.
class LifeOSExporter {
  LifeOSExporter({
    required TaskRepository tasks,
    required HabitRepository habits,
    this.appVersion = '0.1.0',
  })  : _tasks = tasks,
        _habits = habits;

  final TaskRepository _tasks;
  final HabitRepository _habits;
  final String appVersion;

  /// Schema version of the envelope; breaking changes bump this (export
  /// contract rule 4).
  static const int schemaVersion = 1;

  /// Builds the complete envelope in memory (read-only — no writes happen
  /// here, so a failure cannot modify data).
  Future<Map<String, dynamic>> buildEnvelope() async {
    final taskRows = await _tasks.all();
    final habitRows = await _habits.all();
    final entryRows = await _habits.allEntries();

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'domains': <String, dynamic>{
        'tasks': <String, dynamic>{
          'tasks': [for (final task in taskRows) _taskToJson(task)],
        },
        'habits': <String, dynamic>{
          'habits': [for (final habit in habitRows) _habitToJson(habit)],
          'entries': [for (final entry in entryRows) _entryToJson(entry)],
        },
      },
    };
  }

  Map<String, dynamic> _taskToJson(Task task) => <String, dynamic>{
        'id': task.id,
        'title': task.title,
        'dueDate': task.dueDate == null ? null : isoDate(task.dueDate!),
        'status': task.status.name,
        'position': task.position,
        'createdAt': task.createdAt.toUtc().toIso8601String(),
        'updatedAt': task.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _habitToJson(Habit habit) => <String, dynamic>{
        'id': habit.id,
        'name': habit.name,
        'schedule': habit.schedule.type == ScheduleType.daily
            ? <String, dynamic>{'type': 'daily'}
            : <String, dynamic>{
                'type': 'weekly',
                'daysOfWeek': (habit.schedule.daysOfWeek!.toList()..sort()),
              },
        'createdAt': habit.createdAt.toUtc().toIso8601String(),
        'updatedAt': habit.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _entryToJson(HabitEntry entry) => <String, dynamic>{
        'id': entry.id,
        'habitId': entry.habitId,
        'date': isoDate(entry.date),
        'completedAt': entry.completedAt.toUtc().toIso8601String(),
      };

  /// Serializes the envelope to pretty-printed JSON at [target].
  ///
  /// Throws [ExportException] on write failure (storage full / unwritable
  /// target). User data is never touched — retry after fixing the target.
  Future<File> writeTo(File target) async {
    final envelope = await buildEnvelope();
    final json = const JsonEncoder.withIndent('  ').convert(envelope);
    try {
      await target.parent.create(recursive: true);
      await target.writeAsString(json, flush: true);
    } on FileSystemException catch (error) {
      throw ExportException('Could not write export: ${error.message}');
    }
    return target;
  }
}