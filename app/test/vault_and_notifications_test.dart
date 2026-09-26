import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/notifications_screen.dart';
import 'package:lifeos_app/notifications/notification_service.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpNotifications(WidgetTester tester) async {
    final executor = openInMemoryExecutor();
    addTearDown(executor.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('NotificationsScreen lists the three surviving schedules and triggers a test alert',
      (tester) async {
    setPhoneSize(tester);
    await pumpNotifications(tester);

    expect(find.text('🔔 Notifications & Alerts'), findsOneWidget);
    expect(find.text('Task deadlines'), findsOneWidget);
    expect(find.text('Start a focus block'), findsOneWidget);
    expect(find.text('Habit check-in'), findsOneWidget);

    // Schedules for the removed domains must not survive the prune.
    expect(find.text('Morning Kickstart'), findsNothing);
    expect(find.text('Daily Reflection & Review'), findsNothing);
    expect(find.text('Sleep Bedtime'), findsNothing);
    expect(find.text('Evening Routine'), findsNothing);

    final testButtons = find.text('Test Alert');
    expect(testButtons, findsWidgets);
    await tester.tap(testButtons.first);
    await tester.pumpAndSettle();
  });

  test('a fresh install seeds exactly the three surviving defaults', () async {
    final service = NotificationService();
    final schedules = await service.getSchedules();

    expect(
      schedules.map((s) => s.key),
      ['task_deadlines', 'time_tracking', 'habits_check'],
    );
    expect(schedules.every((s) => s.isEnabled), isTrue);
  });

  test('stale schedules from removed domains are pruned on read', () async {
    // Simulate an install that persisted the old 7-item schedule set.
    final legacy = <Map<String, dynamic>>[
      {'key': 'morning_rituals', 'title': 'Morning Kickstart', 'hour': 7, 'minute': 0, 'isEnabled': true},
      {'key': 'task_deadlines', 'title': 'Task deadlines', 'hour': 9, 'minute': 0, 'isEnabled': true},
      {'key': 'sleep_bedtime', 'title': 'Sleep Bedtime', 'hour': 22, 'minute': 30, 'isEnabled': true},
    ];
    SharedPreferences.setMockInitialValues({
      'notifications.schedules_v1': jsonEncode(legacy),
    });

    final service = NotificationService();
    final schedules = await service.getSchedules();

    expect(
      schedules.map((s) => s.key),
      // Sorted by time: task_deadlines 09:00, time_tracking 11:00,
      // habits_check 13:30.
      ['task_deadlines', 'time_tracking', 'habits_check'],
    );
    expect(schedules.any((s) => s.key == 'morning_rituals'), isFalse);
    expect(schedules.any((s) => s.key == 'sleep_bedtime'), isFalse);
  });
}
