import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/database/gamification_database.dart';
import 'src/gamification_summary.dart';
import 'src/repositories/gamification_repository.dart';

class GamificationModule extends ModuleDescriptor {
  GamificationModule(GamificationDatabase database)
      : _repository = GamificationRepository(database);

  final GamificationRepository _repository;
  late final GamificationSummaryBuilder _builder =
      GamificationSummaryBuilder(_repository);

  @override
  String get key => 'gamification';

  @override
  String get name => 'LifeXP & Mastery';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return false;
  }
}
