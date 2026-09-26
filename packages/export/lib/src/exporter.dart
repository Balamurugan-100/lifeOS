import 'dart:convert';
import 'dart:io';

import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

/// Raised when an export cannot be produced or written (T070 edge case).
class ExportException implements Exception {
  ExportException(this.message);

  final String message;

  @override
  String toString() => 'ExportException: $message';
}

/// Builds the portable JSON export envelope and Daily Markdown Digests.
///
/// Scoped to the three surviving domains (tasks + tracked time, habits,
/// finance). Every optional domain is nullable so a partial install still
/// produces a valid envelope.
class LifeOSExporter {
  LifeOSExporter({
    required TaskRepository tasks,
    required HabitRepository habits,
    required TimeRepository time,
    FinanceRepository? finance,
    this.appVersion = '0.1.0',
  })  : _tasks = tasks,
        _habits = habits,
        _time = time,
        _finance = finance;

  final TaskRepository _tasks;
  final HabitRepository _habits;

  /// Tracked work sessions live in the Tasks domain, so the exporter reads them
  /// through the time repository rather than a second domain dependency.
  final TimeRepository _time;
  final FinanceRepository? _finance;
  final String appVersion;

  static const int schemaVersion = 1;

  Future<Map<String, dynamic>> buildEnvelope() async {
    final taskRows = await _tasks.all();
    final habitRows = await _habits.all();
    final entryRows = await _habits.allEntries();
    final sessions = await _time.allTimeSessions();

    final totals = await _time.totalsByTask();

    final domains = <String, dynamic>{
      'tasks': <String, dynamic>{
        'tasks': [for (final task in taskRows) _taskToJson(task, totals[task.id])],
        'timeSessions': [for (final s in sessions) _sessionToJson(s)],
      },
      'habits': <String, dynamic>{
        'habits': [for (final habit in habitRows) _habitToJson(habit)],
        'entries': [for (final entry in entryRows) _entryToJson(entry)],
      },
    };

    if (_finance != null) {
      final accounts = await _finance.getAccounts(includeArchived: true);
      final transactions = await _finance.getTransactions(limit: 10000);
      final budgets = await _finance.getBudgets();
      domains['finance'] = <String, dynamic>{
        'accounts': [for (final acc in accounts) _accountToJson(acc)],
        'transactions': [for (final tx in transactions) _transactionToJson(tx)],
        'budgets': [for (final b in budgets) _budgetToJson(b)],
      };
    }

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'domains': domains,
    };
  }

  /// Builds a Markdown daily digest report for [targetDate].
  Future<String> buildDailyMarkdown(DateTime targetDate) async {
    final dateKey = isoDate(targetDate);
    final buffer = StringBuffer();

    buffer.writeln('# LifeOS Daily Digest - $dateKey\n');

    // 1. Habits completed today
    final habitEntries = await _habits.allEntries();
    final todayHabitsDone = habitEntries
        .where((e) => isoDate(e.date) == dateKey)
        .toList();
    final allHabits = await _habits.all();

    buffer.writeln('## Habits Completed (${todayHabitsDone.length})');
    if (todayHabitsDone.isEmpty) {
      buffer.writeln('_No habits recorded on this day._\n');
    } else {
      for (final hEntry in todayHabitsDone) {
        final habit = allHabits.firstWhere(
          (h) => h.id == hEntry.habitId,
          orElse: () => Habit(
            id: hEntry.habitId,
            name: 'Habit',
            schedule: const HabitSchedule.daily(),
            createdAt: targetDate,
            updatedAt: targetDate,
          ),
        );
        buffer.writeln('- [x] ${habit.name}');
      }
      buffer.writeln('');
    }

    // 2. Tasks completed
    final tasks = await _tasks.all();
    final doneTasks = tasks.where((t) => t.isCompleted).toList();
    buffer.writeln('## Tasks Completed (${doneTasks.length})');
    if (doneTasks.isEmpty) {
      buffer.writeln('_No tasks marked complete._\n');
    } else {
      for (final t in doneTasks) {
        buffer.writeln('- [x] ${t.title}');
      }
      buffer.writeln('');
    }

    // 3. Time tracked — bucketed by the user's local calendar day, matching
    //    TimeRepository.totalSecondsForDay (a session started at 23:30 local
    //    belongs to that local day even though it is already "tomorrow" in UTC).
    final daySessions = (await _time.allTimeSessions())
        .where((s) => isoDate(s.startedAt.toLocal()) == dateKey)
        .toList();
    final totalMins =
        daySessions.fold<int>(0, (sum, s) => sum + s.durationSeconds) ~/ 60;
    final taskTitles = {for (final t in tasks) t.id: t.title};

    buffer.writeln('## Time Tracked ($totalMins min)');
    if (daySessions.isEmpty) {
      buffer.writeln('_No tracked time on this day._\n');
    } else {
      for (final s in daySessions) {
        final title = taskTitles[s.taskId] ?? 'Unlinked session';
        final mins = s.durationSeconds ~/ 60;
        buffer.writeln('- **$title** — $mins min${s.isPomodoro ? ' (pomodoro)' : ''}');
      }
      buffer.writeln('');
    }

    // 4. Finance activity
    if (_finance != null) {
      final txs = await _finance.getTransactions(limit: 1000);
      final dayTxs = txs.where((t) => isoDate(t.date) == dateKey).toList();

      buffer.writeln('## Finance Activity (${dayTxs.length} txs)');
      if (dayTxs.isEmpty) {
        buffer.writeln('_No transactions on this day._\n');
      } else {
        for (final tx in dayTxs) {
          final sign = tx.type == TransactionType.expense ? '-' : '+';
          buffer.writeln(
              '- **$sign\u{20B9}${tx.amount.toStringAsFixed(2)}** \u2022 ${tx.note ?? tx.type.name}');
        }
        buffer.writeln('');
      }
    }

    buffer.writeln('---\n_Exported from LifeOS_');
    return buffer.toString();
  }

  /// Writes the daily Markdown or JSON export for [targetDate] to [target].
  Future<File> writeDailyExportTo(
    DateTime targetDate,
    File target, {
    bool asMarkdown = true,
  }) async {
    try {
      await target.parent.create(recursive: true);
      if (asMarkdown) {
        final content = await buildDailyMarkdown(targetDate);
        await target.writeAsString(content, flush: true);
      } else {
        final envelope = await buildEnvelope();
        final json = const JsonEncoder.withIndent('  ').convert(envelope);
        await target.writeAsString(json, flush: true);
      }
    } on FileSystemException catch (error) {
      throw ExportException('Could not write daily export: ${error.message}');
    }
    return target;
  }

  Map<String, dynamic> _accountToJson(Account acc) => <String, dynamic>{
        'id': acc.id,
        'name': acc.name,
        'type': acc.type.name,
        'currencySymbol': acc.currencySymbol,
        'initialBalance': acc.initialBalance,
        'isArchived': acc.isArchived,
        'lastReconciledAt': acc.lastReconciledAt?.toUtc().toIso8601String(),
        'createdAt': acc.createdAt.toUtc().toIso8601String(),
        'updatedAt': acc.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _transactionToJson(FinanceTransaction tx) =>
      <String, dynamic>{
        'id': tx.id,
        'accountId': tx.accountId,
        'toAccountId': tx.toAccountId,
        'type': tx.type.name,
        'categoryId': tx.categoryId,
        'amount': tx.amount,
        'date': tx.date.toUtc().toIso8601String(),
        'note': tx.note,
        'isReconciliationAdjustment': tx.isReconciliationAdjustment,
        'createdAt': tx.createdAt.toUtc().toIso8601String(),
        'updatedAt': tx.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _budgetToJson(CategoryBudget b) => <String, dynamic>{
        'id': b.id,
        'categoryId': b.categoryId,
        'monthlyLimit': b.monthlyLimit,
        'createdAt': b.createdAt.toUtc().toIso8601String(),
        'updatedAt': b.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _taskToJson(Task task, int? trackedSeconds) =>
      <String, dynamic>{
        'id': task.id,
        'title': task.title,
        'dueDate': task.dueDate == null ? null : isoDate(task.dueDate!),
        'status': task.status.name,
        'position': task.position,
        'priority': task.priority.name,
        'category': task.category,
        'repeat': task.repeat.name,
        'trackedSeconds': trackedSeconds ?? 0,
        'createdAt': task.createdAt.toUtc().toIso8601String(),
        'updatedAt': task.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _sessionToJson(TimeSession session) => <String, dynamic>{
        'id': session.id,
        'taskId': session.taskId,
        'startedAt': session.startedAt.toUtc().toIso8601String(),
        'endedAt': session.endedAt?.toUtc().toIso8601String(),
        'durationSeconds': session.durationSeconds,
        'isPomodoro': session.isPomodoro,
        'label': session.label,
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
