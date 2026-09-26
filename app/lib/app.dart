import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_finance/lifeos_finance.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'bootstrap/database.dart';
import 'home/home_screen.dart';
import 'theme/theme_controller.dart';

/// Route observer used to refresh the home overview whenever the user
/// returns to it (FR-003, SC-002).
final RouteObserver<ModalRoute<void>> homeRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// The single shared SQLite connection (US4: local-first; every domain
/// database opens against this one executor). Tests override this with an
/// in-memory executor.
final databaseExecutorProvider = FutureProvider<QueryExecutor>((ref) async {
  return openAppDatabase();
});

final taskDatabaseProvider = FutureProvider<TaskDatabase>((ref) async {
  final db = TaskDatabase(await ref.watch(databaseExecutorProvider.future));
  await db.ensureTables();
  return db;
});

final habitDatabaseProvider = FutureProvider<HabitDatabase>((ref) async {
  final db = HabitDatabase(await ref.watch(databaseExecutorProvider.future));
  await db.ensureTables();
  return db;
});

final financeDatabaseProvider = FutureProvider<FinanceDatabase>((ref) async {
  final db = FinanceDatabase(await ref.watch(databaseExecutorProvider.future));
  await db.ensureTables();
  return db;
});

final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  return TaskRepository(await ref.watch(taskDatabaseProvider.future));
});

/// Time tracking and the Pomodoro runner live in the Tasks domain, so the
/// time repository is built on the task database rather than a separate one.
final timeRepositoryProvider = FutureProvider<TimeRepository>((ref) async {
  return TimeRepository(await ref.watch(taskDatabaseProvider.future));
});

final habitRepositoryProvider = FutureProvider<HabitRepository>((ref) async {
  return HabitRepository(await ref.watch(habitDatabaseProvider.future));
});

final financeRepositoryProvider = FutureProvider<FinanceRepository>((ref) async {
  return FinanceRepository(await ref.watch(financeDatabaseProvider.future));
});

/// The LifeOS app shell: one `MaterialApp`, one home, per-domain
/// navigation targets, and dynamic theme support (Dark/Light).
class LifeOSApp extends ConsumerWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'LifeOS',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorObservers: [homeRouteObserver],
      home: const HomeScreen(),
    );
  }
}