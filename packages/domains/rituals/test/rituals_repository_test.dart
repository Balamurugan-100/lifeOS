import 'package:lifeos_rituals/lifeos_rituals.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late RitualsDatabase db;
  late RitualsRepository repo;

  setUp(() async {
    db = RitualsDatabase(openInMemoryExecutor());
    await db.ensureTables();
    repo = RitualsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('seeds default morning and evening rituals if empty', () async {
    final rituals = await repo.getRituals();
    expect(rituals.length, 2);
    expect(rituals.any((r) => r.type == RitualType.morning), isTrue);
    expect(rituals.any((r) => r.type == RitualType.evening), isTrue);
    expect(rituals.first.steps.length, greaterThanOrEqualTo(3));
  });

  test('toggles step completion and tracks execution', () async {
    final rituals = await repo.getRituals();
    final morning = rituals.firstWhere((r) => r.type == RitualType.morning);
    final firstStep = morning.steps.first;

    expect(firstStep.isCompleted, isFalse);

    await repo.toggleStepCompletion(morning.id, firstStep.id);

    final updated = await repo.getRituals();
    final updatedMorning = updated.firstWhere((r) => r.id == morning.id);
    expect(updatedMorning.steps.first.isCompleted, isTrue);
    expect(updatedMorning.completedStepsCount, 1);
  });

  test('completing all steps marks ritual completed for today', () async {
    final rituals = await repo.getRituals();
    final morning = rituals.firstWhere((r) => r.type == RitualType.morning);

    for (final step in morning.steps) {
      await repo.toggleStepCompletion(morning.id, step.id);
    }

    final updated = await repo.getRituals();
    final updatedMorning = updated.firstWhere((r) => r.id == morning.id);
    expect(updatedMorning.isCompletedToday, isTrue);
    expect(updatedMorning.streak, 1);
  });
}
