import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_controller.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationScheduleItem {
  const NotificationScheduleItem({
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
        'morning_rituals' => Icons.wb_sunny_rounded,
        'task_deadlines' => Icons.checklist_rounded,
        'focus_sprint' => Icons.timer_outlined,
        'habits_check' => Icons.local_fire_department_rounded,
        'evening_routine' => Icons.nightlight_round,
        'daily_reflection' => Icons.edit_note_rounded,
        'sleep_bedtime' => Icons.bedtime_rounded,
        _ => Icons.notifications_active_rounded,
      };

  String get formattedTime {
    final t = time;
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $period';
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

  static List<NotificationScheduleItem> get _defaults => [
        NotificationScheduleItem(
          key: 'morning_rituals',
          title: '🌅 Morning Kickstart',
          message: 'Time for your morning routine: hydrate, review today\'s priorities, and focus.',
          hour: 7,
          minute: 0,
          isEnabled: true,
          iconCode: Icons.wb_sunny_rounded.codePoint,
          colorHex: '#F59E0B',
        ),
        NotificationScheduleItem(
          key: 'task_deadlines',
          title: '📋 Task Deadlines & Action Queue',
          message: 'Check your high-priority items and upcoming deliverables due today.',
          hour: 9,
          minute: 0,
          isEnabled: true,
          iconCode: Icons.checklist_rounded.codePoint,
          colorHex: '#38BDF8',
        ),
        NotificationScheduleItem(
          key: 'focus_sprint',
          title: '⏱️ Deep Work Block',
          message: 'Ready for a distraction-free 25-minute focus session? Get in the zone.',
          hour: 11,
          minute: 0,
          isEnabled: true,
          iconCode: Icons.timer_outlined.codePoint,
          colorHex: '#F43F5E',
        ),
        NotificationScheduleItem(
          key: 'habits_check',
          title: '🔥 Habit Streaks Alert',
          message: 'Keep your streaks unbroken! Complete your scheduled habits for the day.',
          hour: 13,
          minute: 30,
          isEnabled: true,
          iconCode: Icons.local_fire_department_rounded.codePoint,
          colorHex: '#10B981',
        ),
        NotificationScheduleItem(
          key: 'evening_routine',
          title: '🌙 Evening Wind-down',
          message: 'Time to close open loops, clear the inbox, and start winding down.',
          hour: 20,
          minute: 30,
          isEnabled: true,
          iconCode: Icons.nightlight_round.codePoint,
          colorHex: '#8B5CF6',
        ),
        NotificationScheduleItem(
          key: 'daily_reflection',
          title: '📖 Daily Reflection & Review',
          message: 'Log your daily mood score, wins, and calibrate tomorrow\'s 3 Big Bets.',
          hour: 21,
          minute: 30,
          isEnabled: true,
          iconCode: Icons.edit_note_rounded.codePoint,
          colorHex: '#F59E0B',
        ),
        NotificationScheduleItem(
          key: 'sleep_bedtime',
          title: '💤 Sleep & Rest Target',
          message: 'Screens off. Log your sleep targets and prepare for restorative sleep.',
          hour: 22,
          minute: 30,
          isEnabled: true,
          iconCode: Icons.bedtime_rounded.codePoint,
          colorHex: '#8B5CF6',
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
      return list.map((e) => NotificationScheduleItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaults;
    }
  }

  Future<void> saveSchedules(List<NotificationScheduleItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_kSchedulesKey, encoded);
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

  void triggerLocalNotification(BuildContext context, NotificationScheduleItem item) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NeonPalette.cyan, width: 1.5),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NeonPalette.cyan.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: NeonPalette.cyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
