import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../theme/theme_controller.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

class NotificationScheduleItem {
  NotificationScheduleItem({
    required this.key,
    required this.title,
    required this.message,
    required this.hour,
    required this.minute,
    required this.isEnabled,
    required this.iconCode,
    required this.colorHex,
  });

  final String key;
  final String title;
  final String message;
  final int hour;
  final int minute;
  final bool isEnabled;
  final int iconCode;
  final String colorHex;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  IconData get iconData => switch (key) {
        'task_deadlines' => Icons.checklist_rounded,
        'time_tracking' => Icons.timer_outlined,
        'habits_check' => Icons.local_fire_department_rounded,
        _ => Icons.notifications_active_rounded,
      };

  String get formattedTime {
    final t = time;
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  int get idCode {
    return key.hashCode.abs() % 100000;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'message': message,
        'hour': hour,
        'minute': minute,
        'isEnabled': isEnabled,
        'iconCode': iconCode,
        'colorHex': colorHex,
      };

  factory NotificationScheduleItem.fromJson(Map<String, dynamic> json) {
    return NotificationScheduleItem(
      key: json['key'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      hour: json['hour'] as int? ?? 9,
      minute: json['minute'] as int? ?? 0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      iconCode: json['iconCode'] as int? ?? Icons.notifications.codePoint,
      colorHex: json['colorHex'] as String? ?? '#38BDF8',
    );
  }

  NotificationScheduleItem copyWith({
    String? title,
    String? message,
    int? hour,
    int? minute,
    bool? isEnabled,
  }) {
    return NotificationScheduleItem(
      key: key,
      title: title ?? this.title,
      message: message ?? this.message,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      iconCode: iconCode,
      colorHex: colorHex,
    );
  }
}

class NotificationService {
  static const _kSchedulesKey = 'notifications.schedules_v1';
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fallback
    }

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );
      
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
      
      _localNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}
        
    await _syncSchedulesToSystem();
  }

  Future<void> _syncSchedulesToSystem() async {
    try {
      final schedules = await getSchedules();
      
      await _localNotificationsPlugin.cancelAll();
      
      for (final schedule in schedules) {
        if (!schedule.isEnabled) continue;
        
        final now = tz.TZDateTime.now(tz.local);
        var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, schedule.hour, schedule.minute);
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        
        await _localNotificationsPlugin.zonedSchedule(
          id: schedule.idCode,
          title: schedule.title,
          body: schedule.message,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'lifeos_reminders_id',
              'LifeOS Reminders',
              channelDescription: 'Daily reminders for LifeOS tasks and habits',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {
      // Ignore errors in test environment (missing plugin channel)
    }
  }

  /// The three reminders that map onto the surviving domains. Anything a
  /// previous install persisted for a removed domain is dropped by
  /// [getSchedules], which filters against these keys.
  static const List<String> _knownKeys = [
    'task_deadlines',
    'time_tracking',
    'habits_check',
  ];

  static List<NotificationScheduleItem> get _defaults => [
        NotificationScheduleItem(
          key: 'task_deadlines',
          title: 'Task deadlines',
          message: 'Check the high-priority items due today and pick one to start.',
          hour: 9,
          minute: 0,
          isEnabled: true,
          iconCode: Icons.checklist_rounded.codePoint,
          colorHex: '#5FA8A0',
        ),
        NotificationScheduleItem(
          key: 'time_tracking',
          title: 'Start a focus block',
          message: 'Open a task and run a 25-minute Pomodoro to log your time.',
          hour: 11,
          minute: 0,
          isEnabled: true,
          iconCode: Icons.timer_outlined.codePoint,
          colorHex: '#7C8DA6',
        ),
        NotificationScheduleItem(
          key: 'habits_check',
          title: 'Habit check-in',
          message: 'Keep the streak alive — tick off the habits you planned for today.',
          hour: 13,
          minute: 30,
          isEnabled: true,
          iconCode: Icons.local_fire_department_rounded.codePoint,
          colorHex: '#7FA86F',
        ),
      ];

  Future<List<NotificationScheduleItem>> getSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSchedulesKey);
    if (raw == null) {
      await saveSchedules(_defaults);
      return _defaults;
    }

    try {
      final list = jsonDecode(raw) as List;
      final parsed = list
          .map((e) => NotificationScheduleItem.fromJson(e as Map<String, dynamic>))
          .where((i) => _knownKeys.contains(i.key))
          .toList();
      // Fold anything a previous install persisted for a since-removed domain
      // into a freshly seeded default, and repersist so the prune sticks.
      for (final fallback in _defaults) {
        if (!parsed.any((i) => i.key == fallback.key)) {
          parsed.add(fallback);
        }
      }
      parsed.sort(
        (a, b) => a.hour == b.hour ? a.minute.compareTo(b.minute) : a.hour.compareTo(b.hour),
      );
      if (parsed.length != list.length) {
        await saveSchedules(parsed);
      }
      return parsed;
    } catch (_) {
      return _defaults;
    }
  }

  Future<void> saveSchedules(List<NotificationScheduleItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_kSchedulesKey, encoded);
    await _syncSchedulesToSystem();
  }

  Future<void> updateSchedule(NotificationScheduleItem updated) async {
    final all = await getSchedules();
    final index = all.indexWhere((i) => i.key == updated.key);
    if (index != -1) {
      all[index] = updated;
    } else {
      all.add(updated);
    }
    await saveSchedules(all);
  }

  Future<void> resetToDefaults() async {
    await saveSchedules(_defaults);
  }

  Future<void> triggerLocalNotification(BuildContext context, NotificationScheduleItem item) async {
    try {
      await _localNotificationsPlugin.show(
        id: item.idCode,
        title: 'Test: ${item.title}',
        body: item.message,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'lifeos_reminders_id',
            'LifeOS Reminders',
            channelDescription: 'Daily reminders for LifeOS tasks and habits',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Ignore in tests
    }
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LifeOSPalette.teal, width: 1.5),
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LifeOSPalette.teal.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: LifeOSPalette.teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push Sent: ${item.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Check your lock screen or notification center.',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
