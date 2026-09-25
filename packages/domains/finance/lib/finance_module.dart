import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/database/finance_database.dart';
import 'src/finance_summary.dart';
import 'src/repositories/finance_repository.dart';

/// The Finance domain's [ModuleDescriptor].
class FinanceModule extends ModuleDescriptor {
  FinanceModule(FinanceDatabase database)
      : _repository = FinanceRepository(database);

  final FinanceRepository _repository;
  late final FinanceSummaryBuilder _builder =
      FinanceSummaryBuilder(_repository);

  @override
  String get key => 'finance';

  @override
  String get name => 'Finance';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    // Finance highlights (reconciliation or budget review) navigate to domain screen
    return false;
  }
}
