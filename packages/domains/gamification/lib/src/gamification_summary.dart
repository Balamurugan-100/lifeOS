import 'package:lifeos_core/lifeos_core.dart';

import 'repositories/gamification_repository.dart';

class GamificationSummaryBuilder {
  GamificationSummaryBuilder(this._repository);

  final GamificationRepository _repository;

  Future<DomainSummary> build() async {
    final profile = await _repository.getProfile();
    final counts = <String, int>{};
    if (profile.totalXp > 0) {
      counts['level'] = profile.level;
      counts['total xp'] = profile.totalXp;
    }

    final highlighted = <HighlightedItem>[];
    if (profile.totalXp > 0) {
      highlighted.add(
        HighlightedItem(
          id: 'rank',
          title: '${profile.rankBadgeIcon} Level ${profile.level}: ${profile.rankTitle}',
          subtitle:
              '${profile.xpIntoCurrentLevel}/${profile.xpRequiredForCurrentLevel} XP to next level',
          kind: 'gamification.rank',
          action: HighlightAction.openDomain,
        ),
      );
    }

    return DomainSummary(
      domainKey: 'gamification',
      displayName: 'LifeXP & Mastery',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
