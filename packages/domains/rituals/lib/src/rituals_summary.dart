import 'package:lifeos_core/lifeos_core.dart';
import 'repositories/rituals_repository.dart';

class RitualsSummaryBuilder {
  const RitualsSummaryBuilder(this._repo);

  final RitualsRepository _repo;

  Future<DomainSummary> build() async {
    final rituals = await _repo.getRituals();

    final completedCount = rituals.where((r) => r.isCompletedToday).length;
    final anyProgress = rituals.any((r) => r.completedStepsCount > 0);

    final counts = <String, int>{};
    final highlighted = <HighlightedItem>[];

    if (completedCount > 0 || anyProgress) {
      if (completedCount > 0) counts['completed'] = completedCount;
      counts['active'] = rituals.length;

      final incomplete = rituals.where((r) => !r.isCompletedToday).toList();
      if (incomplete.isNotEmpty) {
        final next = incomplete.first;
        highlighted.add(
          HighlightedItem(
            id: next.id,
            kind: 'ritual.incomplete',
            title: next.name,
            subtitle: '${next.completedStepsCount}/${next.steps.length} steps done',
            action: HighlightAction.complete,
          ),
        );
      }
    }

    return DomainSummary(
      domainKey: 'rituals',
      displayName: 'Rituals & Routines',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
