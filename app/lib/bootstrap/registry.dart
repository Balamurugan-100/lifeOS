import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_focus/lifeos_focus.dart';
import 'package:lifeos_gamification/lifeos_gamification.dart';
import 'package:lifeos_goals/lifeos_goals.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_journal/lifeos_journal.dart';
import 'package:lifeos_notes/lifeos_notes.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';

/// SharedPreferences key holding the JSON map of module key -> enabled.
const String _enabledStateKey = 'modules.enabled';

/// Builds the app's module registry: Tasks, Habits, Finance, Journal, Focus, Goals, Notes descriptors
/// with enable/disable state persisted to SharedPreferences (FR-005).
Future<ModuleRegistry> buildModuleRegistry({
  required TaskDatabase taskDatabase,
  required HabitDatabase habitDatabase,
  required FinanceDatabase financeDatabase,
  required JournalDatabase journalDatabase,
  required FocusDatabase focusDatabase,
  required GoalDatabase goalDatabase,
  required NoteDatabase noteDatabase,
  required GamificationDatabase gamificationDatabase,
  required SharedPreferences prefs,
}) async {
  final registry = ModuleRegistry(
    loadState: () async {
      final raw = prefs.getString(_enabledStateKey);
      if (raw == null) return const {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as bool));
    },
    persistState: (key, enabled) async {
      final raw = prefs.getString(_enabledStateKey);
      final map = raw == null
          ? <String, dynamic>{}
          : (jsonDecode(raw) as Map<String, dynamic>);
      map[key] = enabled;
      await prefs.setString(_enabledStateKey, jsonEncode(map));
    },
  )
    ..register(TasksModule(taskDatabase))
    ..register(HabitsModule(habitDatabase))
    ..register(FinanceModule(financeDatabase))
    ..register(JournalModule(journalDatabase))
    ..register(FocusModule(focusDatabase))
    ..register(GoalsModule(goalDatabase))
    ..register(NotesModule(noteDatabase))
    ..register(GamificationModule(gamificationDatabase));
  await registry.loadState();
  return registry;
}

/// The app's single module registry, built once and shared by every consumer
/// of domain summaries (FR-006: home sees only enabled modules).
final moduleRegistryProvider = FutureProvider<ModuleRegistry>((ref) async {
  final taskDatabase = await ref.watch(taskDatabaseProvider.future);
  final habitDatabase = await ref.watch(habitDatabaseProvider.future);
  final financeDatabase = await ref.watch(financeDatabaseProvider.future);
  final journalDatabase = await ref.watch(journalDatabaseProvider.future);
  final focusDatabase = await ref.watch(focusDatabaseProvider.future);
  final goalDatabase = await ref.watch(goalDatabaseProvider.future);
  final noteDatabase = await ref.watch(noteDatabaseProvider.future);
  final gamificationDatabase =
      await ref.watch(gamificationDatabaseProvider.future);
  final prefs = await SharedPreferences.getInstance();
  return buildModuleRegistry(
    taskDatabase: taskDatabase,
    habitDatabase: habitDatabase,
    financeDatabase: financeDatabase,
    journalDatabase: journalDatabase,
    focusDatabase: focusDatabase,
    goalDatabase: goalDatabase,
    noteDatabase: noteDatabase,
    gamificationDatabase: gamificationDatabase,
    prefs: prefs,
  );
});