import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'bootstrap/database.dart';
import 'home/home_screen.dart';

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
  return TaskDatabase(await ref.watch(databaseExecutorProvider.future));
});

final habitDatabaseProvider = FutureProvider<HabitDatabase>((ref) async {
  return HabitDatabase(await ref.watch(databaseExecutorProvider.future));
});

final taskRepositoryProvider = FutureProvider<TaskRepository>((ref) async {
  return TaskRepository(await ref.watch(taskDatabaseProvider.future));
});

final habitRepositoryProvider = FutureProvider<HabitRepository>((ref) async {
  return HabitRepository(await ref.watch(habitDatabaseProvider.future));
});

/// The LifeOS app shell: one `MaterialApp`, one home, and per-domain
/// navigation targets.
class LifeOSApp extends StatelessWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
        useMaterial3: true,
      ),
      navigatorObservers: [homeRouteObserver],
      home: const HomeScreen(),
    );
  }
}