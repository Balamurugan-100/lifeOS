import 'package:lifeos_core/lifeos_core.dart';
import 'repositories/planner_repository.dart';

class PlannerSummaryBuilder {
  const PlannerSummaryBuilder(this._repo);

  final PlannerRepository _repo;

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<DomainSummary> build() async {
    final today = _today();
    final blocks = await _repo.getBlocksForDate(today);

    final totalBlocks = blocks.length;
    final completedBlocks = blocks.where((b) => b.isCompleted).length;
    final totalMinutes = blocks.fold<int>(0, (sum, b) => sum + b.durationMinutes);

    final counts = <String, int>{};
    if (totalBlocks > 0) {
      counts['scheduled'] = totalBlocks;
      counts['completed'] = completedBlocks;
      counts['plannedMins'] = totalMinutes;
    }

    final highlighted = <HighlightedItem>[];
    final pending = blocks.where((b) => !b.isCompleted).toList();
    if (pending.isNotEmpty) {
      final next = pending.first;
      highlighted.add(
        HighlightedItem(
          id: next.id,
          kind: 'planner.block',
          title: next.title,
          subtitle: '${next.formattedTimeRange} (${next.category.name})',
          action: HighlightAction.complete,
        ),
      );
    }

    return DomainSummary(
      domainKey: 'planner',
      displayName: 'Daily Blueprint',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
