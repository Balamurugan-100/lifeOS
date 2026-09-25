import 'package:lifeos_core/lifeos_core.dart';

import 'repositories/journal_repository.dart';

class JournalSummaryBuilder {
  JournalSummaryBuilder(this._repository);

  final JournalRepository _repository;

  Future<DomainSummary> build() async {
    final today = isoDate(todayLocal());
    final todayEntry = await _repository.getEntryByDate(today);
    final allEntries = await _repository.getAllEntries();
    final avgMood = await _repository.getAverageMoodScore(limit: 7);

    final counts = <String, int>{
      'entries': allEntries.length,
      'logged today': todayEntry != null ? 1 : 0,
    };

    final highlighted = <HighlightedItem>[];
    if (allEntries.isNotEmpty) {
      if (todayEntry == null) {
        highlighted.add(
          const HighlightedItem(
            id: 'today_reflection',
            title: 'Daily Reflection & Mood',
            subtitle: 'Check in with how today is going',
            kind: 'journal.record',
            action: HighlightAction.openDomain,
          ),
        );
      } else {
        highlighted.add(
          HighlightedItem(
            id: todayEntry.id,
            title: 'Today: ${todayEntry.mood.label} ${todayEntry.mood.emoji}',
            subtitle: todayEntry.reflection.isNotEmpty
                ? todayEntry.reflection
                : (todayEntry.gratitude ?? 'Reflection recorded'),
            kind: 'journal.view',
            action: HighlightAction.openDomain,
          ),
        );
      }

      if (avgMood > 0 && allEntries.length >= 3) {
        highlighted.add(
          HighlightedItem(
            id: 'mood_stat',
            title: '7-Day Avg Mood: ${avgMood.toStringAsFixed(1)} / 5.0',
            subtitle: 'Keep recording to unlock deeper insights',
            kind: 'journal.stat',
            action: HighlightAction.openDomain,
          ),
        );
      }
    }

    return DomainSummary(
      domainKey: 'journal',
      displayName: 'Journal & Mood',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
