import 'package:lifeos_planner/lifeos_planner.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late PlannerDatabase db;
  late PlannerRepository repo;

  setUp(() async {
    db = PlannerDatabase(openInMemoryExecutor());
    await db.ensureTables();
    repo = PlannerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates, retrieves, and toggles time blocks', () async {
    final block = await repo.createBlock(
      title: 'Deep Architecture Design',
      date: '2026-09-26',
      startMinute: 540, // 9:00 AM
      durationMinutes: 90, // 90 mins -> 10:30 AM
      category: BlockCategory.focus,
    );

    expect(block.formattedStartTime, '9:00 AM');
    expect(block.formattedEndTime, '10:30 AM');
    expect(block.formattedTimeRange, '9:00 AM - 10:30 AM');

    final blocks = await repo.getBlocksForDate('2026-09-26');
    expect(blocks.length, 1);
    expect(blocks.first.isCompleted, isFalse);

    await repo.toggleBlockCompletion(block.id);

    final updated = await repo.getBlocksForDate('2026-09-26');
    expect(updated.first.isCompleted, isTrue);
  });

  test('updates and deletes time blocks', () async {
    final block = await repo.createBlock(
      title: 'Gym Workout',
      date: '2026-09-26',
      startMinute: 420, // 7:00 AM
      durationMinutes: 60,
      category: BlockCategory.health,
    );

    final modified = block.copyWith(title: 'Morning HIIT & Stretching');
    await repo.updateBlock(modified);

    var blocks = await repo.getBlocksForDate('2026-09-26');
    expect(blocks.first.title, 'Morning HIIT & Stretching');

    await repo.deleteBlock(block.id);
    blocks = await repo.getBlocksForDate('2026-09-26');
    expect(blocks, isEmpty);
  });
}
