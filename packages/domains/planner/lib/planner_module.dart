import 'package:lifeos_core/lifeos_core.dart';
import 'src/repositories/planner_repository.dart';
import 'src/planner_summary.dart';

class PlannerModule extends ModuleDescriptor {
  PlannerModule(this._repo);

  final PlannerRepository _repo;

  @override
  String get key => 'planner';

  @override
  String get name => 'Daily Blueprint';

  @override
  Future<DomainSummary> buildSummary() {
    return PlannerSummaryBuilder(_repo).build();
  }

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    await _repo.toggleBlockCompletion(item.id);
    return true;
  }
}
