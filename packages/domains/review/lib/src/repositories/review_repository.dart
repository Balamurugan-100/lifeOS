import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

import '../database/review_database.dart';
import '../models/weekly_review.dart';

class ReviewRepository {
  ReviewRepository(this._db);

  final ReviewDatabase _db;

  WeeklyReview _mapToDomain(WeeklyReviewData r) {
    List<String> betList = [];
    try {
      final list = jsonDecode(r.bigBets) as List;
      betList = list.map((e) => e.toString()).toList();
    } catch (_) {}

    return WeeklyReview(
      id: r.id,
      weekStartDate: r.weekStartDate,
      rating: r.rating,
      biggestWin: r.biggestWin,
      challengeOrLesson: r.challengeOrLesson,
      bigBets: betList,
      totalTasksCompleted: r.totalTasksCompleted,
      totalHabitCheckins: r.totalHabitCheckins,
      totalFocusMinutes: r.totalFocusMinutes,
      netSavings: r.netSavings,
      averageMood: r.averageMood,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  Future<WeeklyReview> saveReview({
    required String weekStartDate,
    int rating = 4,
    String biggestWin = '',
    String challengeOrLesson = '',
    List<String> bigBets = const [],
    int totalTasksCompleted = 0,
    int totalHabitCheckins = 0,
    int totalFocusMinutes = 0,
    double netSavings = 0.0,
    double averageMood = 4.0,
  }) async {
    final now = utcNow();
    final existing = await (_db.select(_db.weeklyReviews)
          ..where((tbl) => tbl.weekStartDate.equals(weekStartDate)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.weeklyReviews)
            ..where((tbl) => tbl.id.equals(existing.id)))
          .write(
        WeeklyReviewsCompanion(
          rating: Value(rating),
          biggestWin: Value(biggestWin),
          challengeOrLesson: Value(challengeOrLesson),
          bigBets: Value(jsonEncode(bigBets)),
          totalTasksCompleted: Value(totalTasksCompleted),
          totalHabitCheckins: Value(totalHabitCheckins),
          totalFocusMinutes: Value(totalFocusMinutes),
          netSavings: Value(netSavings),
          averageMood: Value(averageMood),
          updatedAt: Value(now),
        ),
      );

      return WeeklyReview(
        id: existing.id,
        weekStartDate: weekStartDate,
        rating: rating,
        biggestWin: biggestWin,
        challengeOrLesson: challengeOrLesson,
        bigBets: bigBets,
        totalTasksCompleted: totalTasksCompleted,
        totalHabitCheckins: totalHabitCheckins,
        totalFocusMinutes: totalFocusMinutes,
        netSavings: netSavings,
        averageMood: averageMood,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
    } else {
      final id = newId();
      await _db.into(_db.weeklyReviews).insert(
            WeeklyReviewsCompanion.insert(
              id: id,
              weekStartDate: weekStartDate,
              rating: Value(rating),
              biggestWin: Value(biggestWin),
              challengeOrLesson: Value(challengeOrLesson),
              bigBets: Value(jsonEncode(bigBets)),
              totalTasksCompleted: Value(totalTasksCompleted),
              totalHabitCheckins: Value(totalHabitCheckins),
              totalFocusMinutes: Value(totalFocusMinutes),
              netSavings: Value(netSavings),
              averageMood: Value(averageMood),
              createdAt: now,
              updatedAt: now,
            ),
          );

      return WeeklyReview(
        id: id,
        weekStartDate: weekStartDate,
        rating: rating,
        biggestWin: biggestWin,
        challengeOrLesson: challengeOrLesson,
        bigBets: bigBets,
        totalTasksCompleted: totalTasksCompleted,
        totalHabitCheckins: totalHabitCheckins,
        totalFocusMinutes: totalFocusMinutes,
        netSavings: netSavings,
        averageMood: averageMood,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  Future<WeeklyReview?> getReviewForWeek(String weekStartDate) async {
    final row = await (_db.select(_db.weeklyReviews)
          ..where((tbl) => tbl.weekStartDate.equals(weekStartDate)))
        .getSingleOrNull();
    return row == null ? null : _mapToDomain(row);
  }

  Future<List<WeeklyReview>> getAllReviews({int limit = 20}) async {
    final rows = await (_db.select(_db.weeklyReviews)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.weekStartDate)])
          ..limit(limit))
        .get();
    return rows.map(_mapToDomain).toList();
  }

  Future<WeeklyReview?> getMostRecentReview() async {
    final list = await getAllReviews(limit: 1);
    return list.isEmpty ? null : list.first;
  }
}
