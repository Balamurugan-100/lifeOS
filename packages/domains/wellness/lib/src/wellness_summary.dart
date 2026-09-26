import 'package:lifeos_core/lifeos_core.dart';
import 'repositories/wellness_repository.dart';

class WellnessSummaryBuilder {
  const WellnessSummaryBuilder(this._repo);

  final WellnessRepository _repo;

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<DomainSummary> build() async {
    final today = _today();
    final todayLog = await _repo.getLogForDate(today);

    final counts = <String, int>{};
    final highlighted = <HighlightedItem>[];

    if (todayLog != null) {
      counts['sleepMins'] = todayLog.sleepDurationMinutes;
      counts['energy'] = todayLog.energyScore;
      counts['waterMl'] = todayLog.waterMl;

      highlighted.add(
        HighlightedItem(
          id: todayLog.id,
          kind: 'wellness.logged',
          title: 'Energy: ${todayLog.energyEmoji}',
          subtitle: '${todayLog.formattedSleepHours} sleep (${todayLog.sleepQualityLabel})',
          action: HighlightAction.complete,
        ),
      );
    }

    return DomainSummary(
      domainKey: 'wellness',
      displayName: 'Sleep & Energy',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
