import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/goal_database.dart';
import '../models/goal.dart';

class GoalRepository {
  GoalRepository(this._db);

  final GoalDatabase _db;

  Goal _mapToDomain(GoalData row) {
    List<GoalMilestone> milestonesList = [];
    try {
      final decoded = jsonDecode(row.milestones);
      if (decoded is List) {
        milestonesList = decoded
            .map((e) => GoalMilestone.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}

    return Goal(
      id: row.id,
      title: row.title,
      description: row.description,
      category: GoalCategory.fromString(row.category),
      status: GoalStatus.fromString(row.status),
      targetValue: row.targetValue,
      currentValue: row.currentValue,
      unit: row.unit,
      targetDate: row.targetDate,
      linkedHabitId: row.linkedHabitId,
      linkedTaskId: row.linkedTaskId,
      milestones: milestonesList,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<Goal> addGoal({
    required String id,
    required String title,
    String description = '',
    required GoalCategory category,
    double targetValue = 100.0,
    double currentValue = 0.0,
    String unit = '%',
    DateTime? targetDate,
    String? linkedHabitId,
    String? linkedTaskId,
    List<GoalMilestone> milestones = const [],
  }) async {
    final now = DateTime.now();
    final newRow = GoalsTableCompanion.insert(
      id: id,
      title: title,
      description: Value(description),
      category: Value(category.name),
      status: const Value('inProgress'),
      targetValue: Value(targetValue),
      currentValue: Value(currentValue),
      unit: Value(unit),
      targetDate: Value(targetDate),
      linkedHabitId: Value(linkedHabitId),
      linkedTaskId: Value(linkedTaskId),
      milestones: Value(jsonEncode(milestones.map((m) => m.toJson()).toList())),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.goalsTable).insert(newRow);
    return Goal(
      id: id,
      title: title,
      description: description,
      category: category,
      targetValue: targetValue,
      currentValue: currentValue,
      unit: unit,
      targetDate: targetDate,
      linkedHabitId: linkedHabitId,
      linkedTaskId: linkedTaskId,
      milestones: milestones,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Goal?> getGoalById(String id) async {
    final row = await (_db.select(_db.goalsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapToDomain(row);
  }

  Future<List<Goal>> getAllGoals({GoalCategory? category, GoalStatus? status}) async {
    final query = _db.select(_db.goalsTable)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            )
      ]);

    if (category != null) {
      query.where((t) => t.category.equals(category.name));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status.name));
    }

    final rows = await query.get();
    return rows.map(_mapToDomain).toList();
  }

  Future<void> updateGoal(Goal goal) async {
    final now = DateTime.now();
    await _db.update(_db.goalsTable).replace(
          GoalData(
            id: goal.id,
            title: goal.title,
            description: goal.description,
            category: goal.category.name,
            status: goal.status.name,
            targetValue: goal.targetValue,
            currentValue: goal.currentValue,
            unit: goal.unit,
            targetDate: goal.targetDate,
            linkedHabitId: goal.linkedHabitId,
            linkedTaskId: goal.linkedTaskId,
            milestones: jsonEncode(goal.milestones.map((m) => m.toJson()).toList()),
            createdAt: goal.createdAt,
            updatedAt: now,
          ),
        );
  }

  Future<void> updateProgress(String id, double newProgress) async {
    final goal = await getGoalById(id);
    if (goal == null) return;
    final isDone = newProgress >= goal.targetValue;
    await updateGoal(
      goal.copyWith(
        currentValue: newProgress,
        status: isDone ? GoalStatus.completed : goal.status,
      ),
    );
  }

  Future<void> toggleMilestone(String goalId, String milestoneId) async {
    final goal = await getGoalById(goalId);
    if (goal == null) return;
    final updatedMilestones = goal.milestones.map((m) {
      if (m.id == milestoneId) {
        return m.copyWith(isCompleted: !m.isCompleted);
      }
      return m;
    }).toList();

    final allDone = updatedMilestones.isNotEmpty &&
        updatedMilestones.every((m) => m.isCompleted);

    await updateGoal(
      goal.copyWith(
        milestones: updatedMilestones,
        status: allDone ? GoalStatus.completed : GoalStatus.inProgress,
      ),
    );
  }

  Future<bool> deleteGoal(String id) async {
    final count =
        await (_db.delete(_db.goalsTable)..where((t) => t.id.equals(id))).go();
    return count > 0;
  }
}
