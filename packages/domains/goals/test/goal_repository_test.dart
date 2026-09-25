import 'package:lifeos_goals/lifeos_goals.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late GoalDatabase database;
  late GoalRepository repository;

  setUp(() async {
    database = GoalDatabase(openInMemoryExecutor());
    await database.customSelect('SELECT 1').get();
    repository = GoalRepository(database);
  });

  tearDown(() => database.close());

  group('Goals Repository Tests', () {
    test('creates goals and updates progress and status', () async {
      final goal = await repository.addGoal(
        id: 'goal_1',
        title: 'Run 100km this month',
        category: GoalCategory.health,
        targetValue: 100.0,
        currentValue: 20.0,
        unit: 'km',
        milestones: [
          const GoalMilestone(id: 'm1', title: 'First 25km', isCompleted: true),
          const GoalMilestone(id: 'm2', title: '50km half way', isCompleted: false),
          const GoalMilestone(id: 'm3', title: '100km finish line', isCompleted: false),
        ],
      );

      expect(goal.progressPercent, 33);
      expect(goal.isCompleted, isFalse);

      await repository.toggleMilestone('goal_1', 'm2');
      final updated = await repository.getGoalById('goal_1');
      expect(updated!.progressPercent, 67);

      await repository.toggleMilestone('goal_1', 'm3');
      final finished = await repository.getGoalById('goal_1');
      expect(finished!.progressPercent, 100);
      expect(finished.status, GoalStatus.completed);
    });

    test('filters goals by category and status', () async {
      await repository.addGoal(
        id: 'g_health',
        title: 'Sleep 8 hours',
        category: GoalCategory.health,
      );
      await repository.addGoal(
        id: 'g_finance',
        title: 'Save ₹50,000 emergency fund',
        category: GoalCategory.finance,
      );

      final healthGoals =
          await repository.getAllGoals(category: GoalCategory.health);
      expect(healthGoals, hasLength(1));
      expect(healthGoals.first.id, 'g_health');
    });
  });
}
