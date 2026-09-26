import 'package:lifeos_core/lifeos_core.dart';
import 'repositories/review_repository.dart';

class ReviewSummaryBuilder {
  const ReviewSummaryBuilder(this._repo);

  final ReviewRepository _repo;

  Future<DomainSummary> build() async {
    final recent = await _repo.getMostRecentReview();

    final counts = <String, int>{};
    final highlighted = <HighlightedItem>[];

    if (recent != null) {
      counts['weekRating'] = recent.rating;
      counts['tasksDone'] = recent.totalTasksCompleted;
      counts['focusMins'] = recent.totalFocusMinutes;

      if (recent.bigBets.isNotEmpty) {
        highlighted.add(
          HighlightedItem(
            id: recent.id,
            kind: 'review.intention',
            title: 'Top Bet: ${recent.bigBets.first}',
            subtitle: 'Week of ${recent.formattedWeekRange}',
            action: HighlightAction.complete,
          ),
        );
      }
    }

    return DomainSummary(
      domainKey: 'review',
      displayName: 'Weekly Review',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
