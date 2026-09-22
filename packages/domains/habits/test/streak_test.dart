// Unit tests for the pure streak derivation (data-model.md derivation rules,
// contracts/README: streak = consecutive present entries ending today or
// yesterday; weekly = consecutive scheduled weeks with a present entry,
// unscheduled days never count as missed).
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:test/test.dart';

void main() {
  // Fixed reference day: Tuesday 2026-09-22.
  final today = DateTime(2026, 9, 22);

  // Current week (W0):  Mon 21 .. Sun 27.
  // Previous week (W-1): Mon 14 .. Sun 20.
  // Two weeks back (W-2): Mon 7 .. Sun 13.
  int streak(Set<DateTime> entries, HabitSchedule schedule) =>
      currentStreak(entryDates: entries, schedule: schedule, today: today);

  DateTime day(int septemberDay) => DateTime(2026, 9, septemberDay);

  group('daily streak', () {
    const daily = HabitSchedule.daily();

    test('consecutive days ending today', () {
      final entries = {day(22), day(21), day(20), day(19)};
      expect(streak(entries, daily), 4);
    });

    test('single entry today', () {
      expect(streak({day(22)}, daily), 1);
    });

    test('no entries', () {
      expect(streak({}, daily), 0);
    });

    test('today missing: streak continues from yesterday (grace)', () {
      final entries = {day(21), day(20), day(19)};
      expect(streak(entries, daily), 3);
    });

    test('today missing but yesterday present only', () {
      expect(streak({day(21)}, daily), 1);
    });

    test('today AND yesterday missing -> 0', () {
      expect(streak({day(20), day(19)}, daily), 0);
    });

    test('a missing day mid-chain resets', () {
      final entries = {day(22), day(21), day(19)}; // 20 missing
      expect(streak(entries, daily), 2);
    });

    test('today missing, yesterday present, day before missing', () {
      final entries = {day(21), day(19)};
      expect(streak(entries, daily), 1);
    });

    test('entries carry time-of-day; only the calendar date counts', () {
      final entries = {DateTime(2026, 9, 22, 23, 59)};
      expect(streak(entries, daily), 1);
    });

    test('walks across a month/DST boundary with normalization', () {
      // Standard-time fall-back day: 2026-11-01 (Sunday). Calendar dates only.
      final novFirst = DateTime(2026, 11, 1);
      final octThirtyFirst = DateTime(2026, 10, 31);
      final result = currentStreak(
        entryDates: {octThirtyFirst, novFirst},
        schedule: daily,
        today: novFirst,
      );
      expect(result, 2);
    });
  });

  group('weekly streak (Mon/Wed/Fri)', () {
    final mwf = HabitSchedule.weekly({1, 3, 5});

    test('one present scheduled day in the current week', () {
      expect(streak({day(23)}, mwf), 1); // Wed of current week
      expect(streak({day(21)}, mwf), 1); // Mon of current week
    });

    test('current + previous week present', () {
      final entries = {day(23), day(14)}; // W0 Wed, W-1 Mon
      expect(streak(entries, mwf), 2);
    });

    test('current week empty: streak counted from previous week (grace)', () {
      final entries = {day(14), day(16), day(7), day(9)}; // W-1 and W-2
      expect(streak(entries, mwf), 2);
    });

    test('an empty past scheduled week breaks the streak', () {
      final entries = {day(23), day(7), day(9)}; // W0 present, W-1 empty
      expect(streak(entries, mwf), 1);
    });

    test('unscheduled weekday never makes a week present', () {
      expect(streak({day(26)}, mwf), 0); // Saturday only
    });

    test('unscheduled weekday never counts as missed', () {
      final entries = {day(26), day(16), day(9)}; // Sat + W-1 + W-2
      expect(streak(entries, mwf), 2);
    });

    test('no entries', () {
      expect(streak({}, mwf), 0);
    });

    test('entries carry time-of-day; only the calendar date counts', () {
      expect(streak({DateTime(2026, 9, 23, 15, 30)}, mwf), 1);
    });

    test('walks across a DST boundary with normalization', () {
      // America-style fall-back: 2026-11-01. Weeks stay Mon..Sun.
      final wedOct28 = DateTime(2026, 10, 28);
      final wedNov4 = DateTime(2026, 11, 4);
      final result = currentStreak(
        entryDates: {wedOct28, wedNov4},
        schedule: mwf,
        today: wedNov4,
      );
      expect(result, 2);
    });
  });

  group('weekly streak (single day)', () {
    final mondays = HabitSchedule.weekly({1});

    test('Monday entry in current week counts', () {
      expect(streak({day(21)}, mondays), 1);
    });

    test('Tuesday (unscheduled) entry does not count', () {
      expect(streak({day(22)}, mondays), 0);
    });

    test('Monday entries in consecutive weeks', () {
      expect(streak({day(21), day(14)}, mondays), 2);
    });
  });
}