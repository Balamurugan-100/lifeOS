import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_wellness/lifeos_wellness.dart';
import 'package:test/test.dart';

void main() {
  late WellnessDatabase db;
  late WellnessRepository repo;

  setUp(() async {
    db = WellnessDatabase(openInMemoryExecutor());
    await db.ensureTables();
    repo = WellnessRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('logs, retrieves, and updates daily sleep and energy', () async {
    final log = await repo.logWellness(
      date: '2026-09-26',
      sleepDurationMinutes: 480, // 8 hours
      sleepQualityScore: 5,
      energyScore: 5,
      waterMl: 2500,
      factors: ['exercise', 'magnesium'],
      notes: 'Woke up feeling fantastic.',
    );

    expect(log.sleepHours, 8.0);
    expect(log.formattedSleepHours, '8h');
    expect(log.energyEmoji, contains('Supercharged'));

    final retrieved = await repo.getLogForDate('2026-09-26');
    expect(retrieved, isNotNull);
    expect(retrieved!.factors, contains('exercise'));
    expect(retrieved.sleepQualityScore, 5);

    // Update log
    final updated = await repo.logWellness(
      date: '2026-09-26',
      sleepDurationMinutes: 450,
      energyScore: 4,
    );

    expect(updated.sleepDurationMinutes, 450);
    expect(updated.energyScore, 4);
  });

  test('calculates 7-day wellness averages accurately', () async {
    await repo.logWellness(
      date: '2026-09-25',
      sleepDurationMinutes: 420, // 7h
      sleepQualityScore: 4,
      energyScore: 4,
    );
    await repo.logWellness(
      date: '2026-09-26',
      sleepDurationMinutes: 480, // 8h
      sleepQualityScore: 5,
      energyScore: 5,
    );

    final avgs = await repo.getAverages(days: 7);
    expect(avgs.avgSleepDurationHours, 7.5);
    expect(avgs.avgEnergyScore, 4.5);
    expect(avgs.avgQualityScore, 4.5);
  });
}
