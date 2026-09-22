// Tests for the home summary contribution (domain-summary-contract.md).
// counts: doneToday / streaksActive (fixed keys); highlighted = up to 3
// scheduled-today-but-undone habits, kind 'habit.today', subtitle 'Streak: N',
// ordered by streak desc then name.
import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightAction;
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart' show openInMemoryExecutor;
import 'package:test/test.dart';

void main() {
  // Fixed reference day: Tuesday 2026-09-22.
  final today = DateTime(2026, 9, 22);

  late HabitDatabase db;
  late HabitRepository repo;
  late HabitSummaryBuilder builder;

  setUp(() {
    db = HabitDatabase(openInMemoryExecutor());
    repo = HabitRepository(db);
    builder = HabitSummaryBuilder(repo);
  });

  tearDown(() => db.close());

  Future<DomainSummary> build() => builder.build(today: today);

  test('empty database -> empty summary with zero counts', () async {
    final summary = await build();
    expect(summary.domainKey, 'habits');
    expect(summary.displayName, 'Habits');
    expect(summary.counts, {'doneToday': 0, 'streaksActive': 0});
    expect(summary.highlighted, isEmpty);
    expect(summary.isEmpty, isTrue);
    expect(summary.refreshedAt.isUtc, isTrue);
  });

  test('doneToday and streaksActive counts with fixtures', () async {
    // dailyA: done today, streak 2  -> doneToday + streaksActive.
    final dailyA = await repo.define('A');
    await repo.record(dailyA.id, today);
    await repo.record(dailyA.id, DateTime(2026, 9, 21));

    // dailyB: done today, streak 1 -> doneToday only.
    final dailyB = await repo.define('B');
    await repo.record(dailyB.id, today);

    // weeklyC (Mon/Wed/Fri): previous week entry -> streak 1, not scheduled
    // today (Tuesday) -> not highlighted.
    final weeklyC = await repo.define('C', schedule: HabitSchedule.weekly({1, 3, 5}));
    await repo.record(weeklyC.id, DateTime(2026, 9, 16));

    // weeklyD (Tue/Thu): scheduled today but not done -> highlighted.
    final weeklyD = await repo.define('D', schedule: HabitSchedule.weekly({2, 4}));
    await repo.record(weeklyD.id, DateTime(2026, 9, 15));

    // dailyE: nothing recorded -> streak 0, scheduled today -> highlighted.
    final dailyE = await repo.define('E');

    final summary = await build();

    expect(summary.counts, {'doneToday': 2, 'streaksActive': 1});

    expect(summary.highlighted, hasLength(2));
    final first = summary.highlighted[0];
    expect(first.id, weeklyD.id);
    expect(first.kind, 'habit.today');
    expect(first.title, 'D');
    expect(first.subtitle, 'Streak: 1');
    expect(first.action, HighlightAction.complete);

    final second = summary.highlighted[1];
    expect(second.id, dailyE.id);
    expect(second.title, 'E');
    expect(second.subtitle, 'Streak: 0');
  });

  test('a weekly habit with an entry today counts as doneToday', () async {
    final habit = await repo.define('Tue', schedule: HabitSchedule.weekly({2}));
    await repo.record(habit.id, today);

    final summary = await build();
    expect(summary.counts['doneToday'], 1);
    expect(summary.counts['streaksActive'], 0); // streak 1 -> not active
    expect(summary.highlighted, isEmpty); // already done today
  });

  test('highlighted capped at 3, ordered by streak desc then name', () async {
    // All daily, none recorded today.
    final echo = await repo.define('Echo'); // streak 5
    for (var i = 1; i <= 5; i++) {
      await repo.record(echo.id, DateTime(2026, 9, 22 - i));
    }

    final alpha = await repo.define('Alpha'); // streak 3
    for (var i = 1; i <= 3; i++) {
      await repo.record(alpha.id, DateTime(2026, 9, 22 - i));
    }

    final bravo = await repo.define('Bravo'); // streak 3
    for (var i = 1; i <= 3; i++) {
      await repo.record(bravo.id, DateTime(2026, 9, 22 - i));
    }

    final delta = await repo.define('Delta'); // streak 1
    await repo.record(delta.id, DateTime(2026, 9, 21));

    final summary = await build();

    expect(summary.counts['doneToday'], 0);
    expect(summary.counts['streaksActive'], 3); // Echo(5), Alpha(3), Bravo(3)
    expect(summary.highlighted, hasLength(3));
    expect(
      summary.highlighted.map((h) => h.title).toList(),
      ['Echo', 'Alpha', 'Bravo'],
    );
    expect(
      summary.highlighted.map((h) => h.subtitle).toList(),
      ['Streak: 5', 'Streak: 3', 'Streak: 3'],
    );
    expect(
      summary.highlighted.every((h) => h.kind == 'habit.today'),
      isTrue,
    );
    expect(
      summary.highlighted.every((h) => h.action == HighlightAction.complete),
      isTrue,
    );
  });

  test('done habits are never highlighted', () async {
    final habit = await repo.define('Done');
    await repo.record(habit.id, today);
    final summary = await build();
    expect(summary.highlighted.where((h) => h.title == 'Done'), isEmpty);
  });

  test('weekly habit on an unscheduled day is never highlighted', () async {
    await repo.define(
      'Weekend',
      schedule: HabitSchedule.weekly({6, 7}), // Sat/Sun
    );
    final summary = await build();
    expect(summary.highlighted, isEmpty);
  });

  test('HighlightedItem ids are stable habit ids', () async {
    final habit = await repo.define('Pending');
    final summary = await build();
    expect(summary.highlighted.single.id, habit.id);
  });
}