import 'package:lifeos_review/lifeos_review.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late ReviewDatabase db;
  late ReviewRepository repo;

  setUp(() async {
    db = ReviewDatabase(openInMemoryExecutor());
    await db.ensureTables();
    repo = ReviewRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('saves, retrieves, and updates weekly review', () async {
    final review = await repo.saveReview(
      weekStartDate: '2026-09-21',
      rating: 5,
      biggestWin: 'Shipped high-impact features ahead of schedule.',
      challengeOrLesson: 'Need to protect morning deep work blocks better.',
      bigBets: [
        'Scale mobile test coverage to 100%',
        'Complete monthly budget audit',
        '30m daily reading habit',
      ],
      totalTasksCompleted: 14,
      totalHabitCheckins: 38,
      totalFocusMinutes: 480,
      netSavings: 15000.0,
      averageMood: 4.8,
    );

    expect(review.rating, 5);
    expect(review.bigBets.length, 3);
    expect(review.formattedWeekRange, 'Sep 21 - Sep 27');

    final retrieved = await repo.getReviewForWeek('2026-09-21');
    expect(retrieved, isNotNull);
    expect(retrieved!.biggestWin, contains('Shipped'));

    final recent = await repo.getMostRecentReview();
    expect(recent, isNotNull);
    expect(recent!.totalTasksCompleted, 14);
  });
}
