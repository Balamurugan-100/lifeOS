import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/database/goal_database.dart';
import 'src/goal_summary.dart';
import 'src/repositories/goal_repository.dart';

class GoalsModule extends ModuleDescriptor {
  GoalsModule(GoalDatabase database) : _repository = GoalRepository(database);

  final GoalRepository _repository;
  late final GoalSummaryBuilder _builder = GoalSummaryBuilder(_repository);

  @override
  String get key => 'goals';

  @override
  String get name => 'Goals & Milestones';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return false;
  }
}
