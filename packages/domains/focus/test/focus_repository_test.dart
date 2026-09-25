import 'package:lifeos_focus/lifeos_focus.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

void main() {
  late FocusDatabase database;
  late FocusRepository repository;

  setUp(() async {
    database = FocusDatabase(openInMemoryExecutor());
    await database.customSelect('SELECT 1').get();
    repository = FocusRepository(database);
  });

  tearDown(() => database.close());

  group('Focus Repository Tests', () {
    test('records focus sessions and computes daily minutes', () async {
      final now = DateTime.now();
      await repository.recordSession(
        id: 'session_1',
        taskId: 'task_123',
        taskTitle: 'Refactor analytics architecture',
        durationSeconds: 1500, // 25 mins
        completedAt: now,
        mode: FocusMode.pomodoro,
      );

      await repository.recordSession(
        id: 'session_2',
        durationSeconds: 3000, // 50 mins
        completedAt: now,
        mode: FocusMode.deepWork,
      );

      final totalMins = await repository.getTodayFocusMinutes(now);
      expect(totalMins, 75);

      final sessions = await repository.getAllSessions();
      expect(sessions, hasLength(2));
      expect(sessions.first.taskTitle, 'Refactor analytics architecture');
    });

    test('retrieves multi-day daily focus minutes distribution', () async {
      final now = DateTime.now();
      await repository.recordSession(
        id: 'session_yesterday',
        durationSeconds: 1800,
        completedAt: now.subtract(const Duration(days: 1)),
        mode: FocusMode.pomodoro,
      );

      final daily = await repository.getDailyFocusMinutes(days: 7);
      expect(daily.keys, hasLength(7));
    });
  });
}
