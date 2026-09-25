import 'package:lifeos_core/lifeos_core.dart';

import 'models/goal.dart';
import 'repositories/goal_repository.dart';

class GoalSummaryBuilder {
  GoalSummaryBuilder(this._repository);

  final GoalRepository _repository;

  Future<DomainSummary> build() async {
    final allGoals = await _repository.getAllGoals();
    final active =
        allGoals.where((g) => g.status == GoalStatus.inProgress).toList();
    final completed =
        allGoals.where((g) => g.status == GoalStatus.completed).toList();

    final counts = <String, int>{
      'active': active.length,
      'completed': completed.length,
    };

    final highlighted = <HighlightedItem>[];
    for (final goal in active.take(2)) {
      highlighted.add(
        HighlightedItem(
          id: goal.id,
          title: '${goal.category.icon} ${goal.title}',
          subtitle:
              '${goal.progressPercent}% completed (${goal.currentValue.toStringAsFixed(0)}/${goal.targetValue.toStringAsFixed(0)} ${goal.unit})',
          kind: 'goals.view',
          action: HighlightAction.openDomain,
        ),
      );
    }

    return DomainSummary(
      domainKey: 'goals',
      displayName: 'Goals & Milestones',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
