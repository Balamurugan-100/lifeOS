import 'package:lifeos_core/lifeos_core.dart';
import 'src/repositories/rituals_repository.dart';
import 'src/rituals_summary.dart';

class RitualsModule extends ModuleDescriptor {
  RitualsModule(this._repo);

  final RitualsRepository _repo;

  @override
  String get key => 'rituals';

  @override
  String get name => 'Rituals & Routines';

  @override
  Future<DomainSummary> buildSummary() {
    return RitualsSummaryBuilder(_repo).build();
  }

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return true;
  }
}
