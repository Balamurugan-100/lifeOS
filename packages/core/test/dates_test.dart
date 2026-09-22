import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

void main() {
  group('calendarDate', () {
    test('normalizes to local midnight', () {
      final t = DateTime(2026, 9, 22, 15, 30, 45);
      final d = calendarDate(t);
      expect(d.year, 2026);
      expect(d.month, 9);
      expect(d.day, 22);
      expect(d.hour, 0);
      expect(d.minute, 0);
      expect(d.second, 0);
    });
  });

  group('isoDate', () {
    test('round-trips', () {
      final d = DateTime(2026, 9, 22);
      expect(isoDate(d), '2026-09-22');
      expect(parseIsoDate('2026-09-22'), d);
    });

    test('rejects malformed input', () {
      expect(parseIsoDate('22-09-2026'), isNull);
      expect(parseIsoDate('2026-13-01'), isNull);
      expect(parseIsoDate('garbage'), isNull);
    });
  });

  group('isSameDay / isBeforeToday', () {
    test('isSameDay compares calendar dates only', () {
      expect(
        isSameDay(DateTime(2026, 9, 22, 8), DateTime(2026, 9, 22, 23)),
        isTrue,
      );
      expect(
        isSameDay(DateTime(2026, 9, 22), DateTime(2026, 9, 23)),
        isFalse,
      );
    });

    test('isBeforeToday is strict before', () {
      expect(isBeforeToday(DateTime(2026, 9, 21), DateTime(2026, 9, 22)), isTrue);
      expect(isBeforeToday(DateTime(2026, 9, 22), DateTime(2026, 9, 22)), isFalse);
      expect(isBeforeToday(DateTime(2026, 9, 23), DateTime(2026, 9, 22)), isFalse);
    });
  });
}