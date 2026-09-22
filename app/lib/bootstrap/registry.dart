import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';

/// SharedPreferences key holding the JSON map of module key -> enabled.
const String _enabledStateKey = 'modules.enabled';

/// Builds the app's module registry: real Tasks and Habits descriptors plus
/// any roadmap stubs, with enable/disable state persisted to
/// SharedPreferences (FR-005) so it survives restarts (T029, T063).
Future<ModuleRegistry> buildModuleRegistry({
  required TaskDatabase taskDatabase,
  required HabitDatabase habitDatabase,
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
    ..register(HabitsModule(habitDatabase));
  await registry.loadState();
  return registry;
}

/// The app's single module registry, built once and shared by every consumer
/// of domain summaries (FR-006: home sees only enabled modules).
final moduleRegistryProvider = FutureProvider<ModuleRegistry>((ref) async {
  final taskDatabase = await ref.watch(taskDatabaseProvider.future);
  final habitDatabase = await ref.watch(habitDatabaseProvider.future);
  final prefs = await SharedPreferences.getInstance();
  return buildModuleRegistry(
    taskDatabase: taskDatabase,
    habitDatabase: habitDatabase,
    prefs: prefs,
  );
});