import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/database/journal_database.dart';
import 'src/journal_summary.dart';
import 'src/repositories/journal_repository.dart';

class JournalModule extends ModuleDescriptor {
  JournalModule(JournalDatabase database)
      : _repository = JournalRepository(database);

  final JournalRepository _repository;
  late final JournalSummaryBuilder _builder =
      JournalSummaryBuilder(_repository);

  @override
  String get key => 'journal';

  @override
  String get name => 'Journal & Mood';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return false;
  }
}
