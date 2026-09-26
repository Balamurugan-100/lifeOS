import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_service.dart';
import '../theme/theme_controller.dart';

final notificationsListProvider = FutureProvider.autoDispose<List<NotificationScheduleItem>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getSchedules();
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _pickTime(NotificationScheduleItem item) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: item.time,
      helpText: 'SELECT NOTIFICATION TIME',
    );

    if (picked != null) {
      final updated = item.copyWith(hour: picked.hour, minute: picked.minute);
      final service = ref.read(notificationServiceProvider);
      await service.updateSchedule(updated);
      ref.invalidate(notificationsListProvider);
    }
  }

  Future<void> _toggleEnabled(NotificationScheduleItem item, bool val) async {
    final updated = item.copyWith(isEnabled: val);
    final service = ref.read(notificationServiceProvider);
    await service.updateSchedule(updated);
    ref.invalidate(notificationsListProvider);
  }

  void _testTrigger(NotificationScheduleItem item) {
    final service = ref.read(notificationServiceProvider);
    service.triggerLocalNotification(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(notificationsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notifications & Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Reset Schedules',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              final service = ref.read(notificationServiceProvider);
              await service.resetToDefaults();
              ref.invalidate(notificationsListProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔄 Reset notifications to recommended timings.')),
                );
              }
            },
          ),
        ],
      ),
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: NeonPalette.cyan)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header description banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: NeonPalette.cyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: NeonPalette.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.schedule_rounded, color: NeonPalette.cyan, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Timed Nudges & LifeOS Rituals',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Configure the exact time you want push reminders for routines, habits, tasks, focus, and night reflections.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Items
              ...items.map((item) {
                return _buildScheduleCard(item, isDark);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(NotificationScheduleItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isEnabled
              ? (isDark ? NeonPalette.borderDark : Colors.grey.shade300)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NeonPalette.cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.iconData, size: 20, color: NeonPalette.cyan),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: item.isEnabled ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                              ),
                            ),
                            Text(
                              item.message,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: item.isEnabled,
                  activeTrackColor: NeonPalette.cyan.withValues(alpha: 0.6),
                  onChanged: (val) => _toggleEnabled(item, val),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => _pickTime(item),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NeonPalette.cyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 14, color: NeonPalette.cyan),
                        const SizedBox(width: 6),
                        Text(
                          item.formattedTime,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NeonPalette.cyan),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 11, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Test Alert', style: TextStyle(fontSize: 12)),
                  onPressed: () => _testTrigger(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
