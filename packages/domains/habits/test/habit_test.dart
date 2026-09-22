// Unit tests for the Habit domain model and schedule value types.
// data-model.md: name 1..100 chars after trim; daily carries no day set;
// weekly is a non-empty subset of 1..7 (Dart DateTime.weekday: 1=Mon..7=Sun).
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:test/test.dart';

void main() {
  final mon = DateTime(2026, 9, 21); // Monday
  final tue = DateTime(2026, 9, 22); // Tuesday
  final wed = DateTime(2026, 9, 23); // Wednesday
  final sat = DateTime(2026, 9, 26); // Saturday
  final sun = DateTime(2026, 9, 27); // Sunday

  group('HabitSchedule.daily', () {
    test('carries no day set', () {
      const schedule = HabitSchedule.daily();
      expect(schedule.type, ScheduleType.daily);
      expect(schedule.daysOfWeek, isNull);
    });

    test('isScheduled is always true', () {
      const schedule = HabitSchedule.daily();
      for (final day in [mon, tue, wed, sat, sun]) {
        expect(schedule.isScheduled(day), isTrue, reason: 'daily $day');
      }
    });
  });

  group('HabitSchedule.weekly validation', () {
    test('empty day set throws ArgumentError', () {
      expect(() => HabitSchedule.weekly({}), throwsArgumentError);
    });

    test('weekdays outside 1..7 throw ArgumentError', () {
      expect(() => HabitSchedule.weekly({0, 1}), throwsArgumentError);
      expect(() => HabitSchedule.weekly({1, 8}), throwsArgumentError);
      expect(() => HabitSchedule.weekly({-1, 3}), throwsArgumentError);
    });

    test('valid weekly schedule keeps type and daysOfWeek', () {
      final schedule = HabitSchedule.weekly({1, 3, 5});
      expect(schedule.type, ScheduleType.weekly);
      expect(schedule.daysOfWeek, {1, 3, 5});
    });

    test('stores daysOfWeek sorted and unmodifiable', () {
      final schedule = HabitSchedule.weekly({3, 5, 1});
      expect(schedule.daysOfWeek!.toList(), [1, 3, 5]);
      expect(schedule.daysOfWeek, isA<Set<int>>());
      expect(() => schedule.daysOfWeek!.add(4), throwsUnsupportedError);
      expect(() => schedule.daysOfWeek!.remove(1), throwsUnsupportedError);
    });
  });

  group('HabitSchedule.weekly isScheduled', () {
    final schedule = HabitSchedule.weekly({1, 3, 5}); // Mon/Wed/Fri

    test('true only on selected weekdays', () {
      expect(schedule.isScheduled(mon), isTrue); // Monday
      expect(schedule.isScheduled(tue), isFalse); // Tuesday
      expect(schedule.isScheduled(wed), isTrue); // Wednesday
      expect(schedule.isScheduled(sat), isFalse); // Saturday
      expect(schedule.isScheduled(sun), isFalse); // Sunday
    });
  });

  group('HabitSchedule value equality', () {
    test('weekly with permuted days is equal (order-independent)', () {
      final a = HabitSchedule.weekly({1, 3, 5});
      final b = HabitSchedule.weekly({3, 5, 1});
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('weekly vs daily never equal', () {
      expect(HabitSchedule.weekly({1, 3, 5}), isNot(const HabitSchedule.daily()));
      expect(HabitSchedule.weekly({1, 3, 5}).hashCode,
          isNot(const HabitSchedule.daily().hashCode));
    });

    test('different day sets not equal', () {
      expect(HabitSchedule.weekly({1, 3, 5}), isNot(HabitSchedule.weekly({1, 3})));
      expect(HabitSchedule.weekly({1, 3, 5}), isNot(HabitSchedule.weekly({1, 3, 7})));
    });
  });

  group('Habit name validation', () {
    DateTime utc() => DateTime.utc(2026, 1, 1);

    Habit make(String name) => Habit(
          id: 'h-1',
          name: name,
          schedule: const HabitSchedule.daily(),
          createdAt: utc(),
          updatedAt: utc(),
        );

    test('empty name throws ArgumentError', () {
      expect(() => make(''), throwsArgumentError);
    });

    test('whitespace-only name throws ArgumentError', () {
      expect(() => make('   '), throwsArgumentError);
      expect(() => make('\t\n '), throwsArgumentError);
    });

    test('name longer than 100 chars throws ArgumentError', () {
      expect(() => make('a' * 101), throwsArgumentError);
    });

    test('name of exactly 100 chars is accepted', () {
      expect(make('a' * 100).name.length, 100);
    });

    test('name is stored trimmed', () {
      expect(make('  Read every day  ').name, 'Read every day');
    });
  });
}