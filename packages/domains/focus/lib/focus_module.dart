import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/database/focus_database.dart';
import 'src/focus_summary.dart';
import 'src/repositories/focus_repository.dart';

class FocusModule extends ModuleDescriptor {
  FocusModule(FocusDatabase database) : _repository = FocusRepository(database);

  final FocusRepository _repository;
  late final FocusSummaryBuilder _builder = FocusSummaryBuilder(_repository);

  @override
  String get key => 'focus';

  @override
  String get name => 'Focus & Pomodoro';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return false;
  }
}
