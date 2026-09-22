/// Calendar-date utilities.
///
/// LifeOS treats "dates" as local calendar dates (data-model.md conventions):
/// a normalized [DateTime] with `hour = minute = second = 0`. Time-of-day is
/// deliberately not part of task due-dates or habit days.
library;

/// Truncates [t] to its local calendar date (midnight on the same day).
DateTime calendarDate(DateTime t) => DateTime(t.year, t.month, t.day);

/// Today's calendar date in the local timezone.
DateTime todayLocal() => calendarDate(DateTime.now());

/// Returns true when [a] and [b] fall on the same local calendar date.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Formats [d] as an ISO-8601 calendar date string, e.g. `2026-09-22`.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parses an `yyyy-MM-dd` string into a local calendar date, or null.
DateTime? parseIsoDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// True when [due] is strictly before [today] (used for the "overdue"
/// derivation; equal dates are still due today, not overdue).
bool isBeforeToday(DateTime due, DateTime today) => due.isBefore(today);