import 'package:lifeos_core/lifeos_core.dart';
import 'src/repositories/wellness_repository.dart';
import 'src/wellness_summary.dart';

class WellnessModule extends ModuleDescriptor {
  WellnessModule(this._repo);

  final WellnessRepository _repo;

  @override
  String get key => 'wellness';

  @override
  String get name => 'Sleep & Energy';

  @override
  Future<DomainSummary> buildSummary() {
    return WellnessSummaryBuilder(_repo).build();
  }

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return true;
  }
}
