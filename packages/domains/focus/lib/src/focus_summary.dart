import 'package:lifeos_core/lifeos_core.dart';

import 'repositories/focus_repository.dart';

class FocusSummaryBuilder {
  FocusSummaryBuilder(this._repository);

  final FocusRepository _repository;

  Future<DomainSummary> build() async {
    final today = todayLocal();
    final todayMinutes = await _repository.getTodayFocusMinutes(today);
    final allSessions = await _repository.getAllSessions();

    final counts = <String, int>{
      'mins today': todayMinutes,
      'sessions': allSessions.length,
    };

    final highlighted = <HighlightedItem>[];
    if (allSessions.isNotEmpty) {
      if (todayMinutes == 0) {
        highlighted.add(
          const HighlightedItem(
            id: 'start_focus',
            title: 'Start 25m Focus Block',
            subtitle: 'Enter flow state on your top priority task',
            kind: 'focus.start',
            action: HighlightAction.openDomain,
          ),
        );
      } else {
        highlighted.add(
          HighlightedItem(
            id: 'focus_today',
            title: '$todayMinutes mins Deep Work today',
            subtitle:
                '${allSessions.where((s) => s.completedAt.day == today.day).length} sessions completed',
            kind: 'focus.stat',
            action: HighlightAction.openDomain,
          ),
        );
      }
    }

    return DomainSummary(
      domainKey: 'focus',
      displayName: 'Focus & Pomodoro',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
