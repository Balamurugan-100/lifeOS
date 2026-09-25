// Repository tests over in-memory drift (lifeos_storage executor; the storage
// package owns the NativeDatabase wiring — no drift/native imports here).
import 'package:drift/drift.dart' show Value;
import 'package:lifeos_core/lifeos_core.dart' show newId;
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show openInMemoryExecutor;
import 'package:test/test.dart';

void main() {
  late HabitDatabase db;
  late HabitRepository repo;

  setUp(() async {
    db = HabitDatabase(openInMemoryExecutor());
    await db.ensureTables();
    repo = HabitRepository(db);
  });

  tearDown(() => db.close());

  DateTime day(int month, int d) => DateTime(2026, month, d);

  group('define', () {
    test('round-trips a daily habit (name trimmed)', () async {
      final habit = await repo.define('  Read every day  ');
      expect(habit.name, 'Read every day');
      expect(habit.schedule.type, ScheduleType.daily);
      expect(habit.schedule.daysOfWeek, isNull);

      final fetched = await repo.byId(habit.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, habit.id);
      expect(fetched.name, 'Read every day');
      expect(fetched.schedule, const HabitSchedule.daily());
    });

    test('round-trips a weekly habit with days', () async {
      final habit = await repo.define(
        'Gym',
        schedule: HabitSchedule.weekly({3, 5, 1}),
      );
      expect(habit.schedule.type, ScheduleType.weekly);
      expect(habit.schedule.daysOfWeek, {1, 3, 5});

      final fetched = await repo.byId(habit.id);
      expect(fetched!.schedule, HabitSchedule.weekly({1, 3, 5}));
    });

    test('invalid name throws ArgumentError', () {
      expect(() => repo.define('   '), throwsArgumentError);
      expect(() => repo.define(''), throwsArgumentError);
      expect(() => repo.define('a' * 101), throwsArgumentError);
    });

    test('timestamps are set (UTC) on definition', () async {
      final habit = await repo.define('Read');
      expect(habit.createdAt.isUtc, isTrue);
      expect(habit.updatedAt.isUtc, isTrue);
    });
  });

  group('all', () {
    test('returns habits in registration order (created_at asc)', () async {
      // drift stores DateTimes as unix seconds, so rapid repo.define() calls
      // could tie on created_at. Insert rows directly with explicit, distinct
      // created_at values to test the ordering query deterministically.
      final base = DateTime.utc(2026, 9, 1, 12);
      Future<String> insertAt(String name, int offsetSeconds) async {
        final id = newId();
        await db.into(db.habits).insert(
              HabitsCompanion.insert(
                id: id,
                name: name,
                scheduleType: 'daily',
                daysOfWeek: const Value(null),
                createdAt: base.add(Duration(seconds: offsetSeconds)),
                updatedAt: base.add(Duration(seconds: offsetSeconds)),
              ),
            );
        return id;
      }

      final a = await insertAt('First', 1);
      final b = await insertAt('Second', 2);
      final c = await insertAt('Third', 3);

      final all = await repo.all();
      expect(all.map((h) => h.id).toList(), [a, b, c]);
      expect(all.map((h) => h.name).toList(), ['First', 'Second', 'Third']);
      expect(all.map((h) => h.schedule).toList(),
          everyElement(const HabitSchedule.daily()));
    });

    test('empty when nothing defined', () async {
      expect(await repo.all(), isEmpty);
    });
  });

  group('byId', () {
    test('returns null for unknown id', () async {
      expect(await repo.byId('missing-id'), isNull);
    });
  });

  group('rename', () {
    test('updates the name and trims', () async {
      final habit = await repo.define('Old');
      await repo.rename(habit.id, '  New name  ');
      final fetched = await repo.byId(habit.id);
      expect(fetched!.name, 'New name');
    });

    test('invalid name throws ArgumentError', () async {
      final habit = await repo.define('Old');
      expect(() => repo.rename(habit.id, ''), throwsArgumentError);
      expect(() => repo.rename(habit.id, 'a' * 101), throwsArgumentError);
    });

    test('refreshes updatedAt', () async {
      final habit = await repo.define('Old');
      await repo.rename(habit.id, 'New');
      final fetched = await repo.byId(habit.id);
      // drift persists DateTimes at unix-second granularity, so compare at
      // second precision. The update must land at or after the definition.
      final defineSec = habit.updatedAt.millisecondsSinceEpoch ~/ 1000;
      final renameSec = fetched!.updatedAt.millisecondsSinceEpoch ~/ 1000;
      expect(renameSec, greaterThanOrEqualTo(defineSec));
      expect(fetched.updatedAt.isUtc, isTrue);
    });
  });

  group('delete', () {
    test('removes the habit and its entries', () async {
      final habit = await repo.define('Read');
      await repo.record(habit.id, day(9, 20));
      await repo.record(habit.id, day(9, 21));
      expect(await repo.entryDates(habit.id), hasLength(2));

      await repo.delete(habit.id);

      expect(await repo.byId(habit.id), isNull);
      expect(await repo.entryDates(habit.id), isEmpty);
    });

    test('no-op for unknown id', () async {
      await repo.delete('missing-id');
    });
  });

  group('record / isDone / unrecord', () {
    test('record makes isDone true for that calendar date', () async {
      final habit = await repo.define('Read');
      // Date carries a time component; only the calendar date is stored.
      await repo.record(habit.id, DateTime(2026, 9, 22, 18, 45));
      expect(await repo.isDone(habit.id, DateTime(2026, 9, 22)), isTrue);
      expect(await repo.isDone(habit.id, DateTime(2026, 9, 21)), isFalse);
    });

    test('record normalizes the stored date', () async {
      final habit = await repo.define('Read');
      await repo.record(habit.id, DateTime(2026, 9, 22, 23, 59));
      final dates = await repo.entryDates(habit.id);
      expect(dates, [DateTime(2026, 9, 22)]);
      expect(dates.first.hour, 0);
      expect(dates.first.minute, 0);
    });

    test('record is idempotent: twice -> one row', () async {
      final habit = await repo.define('Read');
      await repo.record(habit.id, day(9, 22));
      await repo.record(habit.id, day(9, 22));
      expect(await repo.entryDates(habit.id), hasLength(1));
    });

    test('one entry per (habitId, date) enforced by unique constraint',
        () async {
      final habit = await repo.define('Read');
      await repo.record(habit.id, day(9, 22));

      // Bypass the repository: a second row for the same (habitId, date)
      // with a fresh id must violate the composite unique constraint.
      final duplicate = HabitEntriesCompanion.insert(
        id: 'entry-2',
        habitId: habit.id,
        date: day(9, 22),
        completedAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
      );
      await expectLater(
        db.into(db.habitEntries).insert(duplicate),
        throwsA(anything),
      );
      expect(await repo.entryDates(habit.id), hasLength(1));
    });

    test('unrecord removes the row', () async {
      final habit = await repo.define('Read');
      await repo.record(habit.id, day(9, 22));
      expect(await repo.isDone(habit.id, day(9, 22)), isTrue);

      await repo.unrecord(habit.id, day(9, 22));

      expect(await repo.isDone(habit.id, day(9, 22)), isFalse);
      expect(await repo.entryDates(habit.id), isEmpty);
    });

    test('unrecord of an absent day is a no-op', () async {
      final habit = await repo.define('Read');
      await repo.unrecord(habit.id, day(9, 22));
      expect(await repo.entryDates(habit.id), isEmpty);
    });
  });

  group('entryDates', () {
    test('returns ascending calendar dates', () async {
      final habit = await repo.define('Read');
      await repo.record(habit.id, day(9, 20));
      await repo.record(habit.id, day(9, 10));
      await repo.record(habit.id, day(9, 15));
      await repo.record(habit.id, day(10, 5));

      final dates = await repo.entryDates(habit.id);
      expect(dates, [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 20),
        DateTime(2026, 10, 5),
      ]);
    });
  });
}