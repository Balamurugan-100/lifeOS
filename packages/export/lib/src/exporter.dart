import 'dart:convert';
import 'dart:io';

import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_focus/lifeos_focus.dart';
import 'package:lifeos_goals/lifeos_goals.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_journal/lifeos_journal.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

/// Raised when an export cannot be produced or written (T070 edge case).
class ExportException implements Exception {
  ExportException(this.message);

  final String message;

  @override
  String toString() => 'ExportException: $message';
}

/// Builds the portable JSON export envelope and Daily Markdown Digests.
class LifeOSExporter {
  LifeOSExporter({
    required TaskRepository tasks,
    required HabitRepository habits,
    FinanceRepository? finance,
    JournalRepository? journal,
    FocusRepository? focus,
    GoalRepository? goals,
    NotesRepository? notes,
    this.appVersion = '0.1.0',
  })  : _tasks = tasks,
        _habits = habits,
        _finance = finance,
        _journal = journal,
        _focus = focus,
        _goals = goals,
        _notes = notes;

  final TaskRepository _tasks;
  final HabitRepository _habits;
  final FinanceRepository? _finance;
  final JournalRepository? _journal;
  final FocusRepository? _focus;
  final GoalRepository? _goals;
  final NotesRepository? _notes;
  final String appVersion;

  static const int schemaVersion = 1;

  Future<Map<String, dynamic>> buildEnvelope() async {
    final taskRows = await _tasks.all();
    final habitRows = await _habits.all();
    final entryRows = await _habits.allEntries();

    final domains = <String, dynamic>{
      'tasks': <String, dynamic>{
        'tasks': [for (final task in taskRows) _taskToJson(task)],
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

    if (_journal != null) {
      final entries = await _journal.getAllEntries();
      domains['journal'] = <String, dynamic>{
        'entries': [for (final e in entries) e.toJson()],
      };
    }

    if (_focus != null) {
      final sessions = await _focus.getAllSessions();
      domains['focus'] = <String, dynamic>{
        'sessions': [for (final s in sessions) s.toJson()],
      };
    }

    if (_goals != null) {
      final allGoals = await _goals.getAllGoals();
      domains['goals'] = <String, dynamic>{
        'goals': [for (final g in allGoals) g.toJson()],
      };
    }

    if (_notes != null) {
      final allNotes = await _notes.getAllNotes(includeArchived: true);
      domains['notes'] = <String, dynamic>{
        'notes': [for (final n in allNotes) n.toJson()],
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

    buffer.writeln('# 📓 LifeOS Daily Digest - $dateKey\n');

    // 1. Daily Reflection & Mood
    if (_journal != null) {
      final entry = await _journal.getEntryByDate(dateKey);
      if (entry != null) {
        buffer.writeln('## 🌅 Daily Reflection & Mood');
        buffer.writeln('- **Mood:** ${entry.mood.emoji} ${entry.mood.label}');
        if (entry.gratitude != null && entry.gratitude!.isNotEmpty) {
          buffer.writeln('- **Gratitude:** ${entry.gratitude}');
        }
        if (entry.reflection.isNotEmpty) {
          buffer.writeln('- **Reflection:**\n  ${entry.reflection}');
        }
        if (entry.tags.isNotEmpty) {
          buffer.writeln('- **Tags:** ${entry.tags.map((t) => '#$t').join(' ')}');
        }
        buffer.writeln('');
      }
    }

    // 2. Habits Completed Today
    final habitEntries = await _habits.allEntries();
    final todayHabitsDone = habitEntries
        .where((e) => isoDate(e.date) == dateKey)
        .toList();
    final allHabits = await _habits.all();

    buffer.writeln('## 🔁 Habits Completed (${todayHabitsDone.length})');
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

    // 3. Tasks
    final tasks = await _tasks.all();
    final doneTasks = tasks.where((t) => t.isCompleted).toList();
    buffer.writeln('## ✅ Tasks Summary');
    if (doneTasks.isEmpty) {
      buffer.writeln('_No tasks marked complete._\n');
    } else {
      for (final t in doneTasks) {
        buffer.writeln('- [x] ${t.title}');
      }
      buffer.writeln('');
    }

    // 4. Focus / Deep Work
    if (_focus != null) {
      final sessions = await _focus.getAllSessions();
      final daySessions = sessions
          .where((s) => isoDate(s.completedAt) == dateKey)
          .toList();
      final totalMins = daySessions.fold<int>(
          0, (sum, s) => sum + s.durationMinutes);

      buffer.writeln('## ⏱️ Focus & Deep Work ($totalMins mins)');
      if (daySessions.isEmpty) {
        buffer.writeln('_No focus sessions logged._\n');
      } else {
        for (final s in daySessions) {
          buffer.writeln(
              '- **${s.taskTitle ?? s.mode.label}**: ${s.durationMinutes} mins');
        }
        buffer.writeln('');
      }
    }

    // 5. Finance Transactions
    if (_finance != null) {
      final txs = await _finance.getTransactions(limit: 1000);
      final dayTxs =
          txs.where((t) => isoDate(t.date) == dateKey).toList();

      buffer.writeln('## 💰 Finance Activity (${dayTxs.length} txs)');
      if (dayTxs.isEmpty) {
        buffer.writeln('_No transactions on this day._\n');
      } else {
        for (final tx in dayTxs) {
          final sign = tx.type == TransactionType.expense ? '-' : '+';
          buffer.writeln('- **$sign₹${tx.amount.toStringAsFixed(2)}** • ${tx.note ?? tx.type.name}');
        }
        buffer.writeln('');
      }
    }

    // 6. Notes Created / Modified
    if (_notes != null) {
      final notes = await _notes.getAllNotes(includeArchived: true);
      final dayNotes = notes
          .where((n) => isoDate(n.updatedAt) == dateKey)
          .toList();

      if (dayNotes.isNotEmpty) {
        buffer.writeln('## 📝 Notes Updated (${dayNotes.length})');
        for (final n in dayNotes) {
          buffer.writeln('### ${n.title}');
          buffer.writeln('${n.content}\n');
        }
      }
    }

    buffer.writeln('---\n_Exported from LifeOS Personal Operating System_');
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