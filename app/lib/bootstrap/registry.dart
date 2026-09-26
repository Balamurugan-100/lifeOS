import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import '../app.dart';

/// Builds the app's module registry.
///
/// Module settings are gone, so every module is always on and no
/// enable/disable state is persisted — the registry simply exposes the three
/// surviving domains in the order they should appear on the home overview.
ModuleRegistry buildModuleRegistry({
  required TaskDatabase taskDatabase,
  required HabitDatabase habitDatabase,
  required FinanceDatabase financeDatabase,
}) {
  return ModuleRegistry()
    ..register(TasksModule(taskDatabase))
    ..register(HabitsModule(habitDatabase))
    ..register(FinanceModule(financeDatabase));
}

/// The app's single module registry, built once and shared by every consumer
/// of domain summaries.
final moduleRegistryProvider = FutureProvider<ModuleRegistry>((ref) async {
  final taskDatabase = await ref.watch(taskDatabaseProvider.future);
  final habitDatabase = await ref.watch(habitDatabaseProvider.future);
  final financeDatabase = await ref.watch(financeDatabaseProvider.future);
  return buildModuleRegistry(
    taskDatabase: taskDatabase,
    habitDatabase: habitDatabase,
    financeDatabase: financeDatabase,
  );
});
