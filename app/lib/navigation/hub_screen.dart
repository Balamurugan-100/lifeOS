import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/registry_settings.dart';
import '../security/pin_dialog.dart';
import '../security/vault_service.dart';
import '../security/vault_settings_screen.dart';
import '../theme/theme_controller.dart';
import 'analytics_screen.dart';
import 'export_screen.dart';
import 'focus_screen.dart';
import 'goal_screen.dart';
import 'journal_screen.dart';
import 'notes_screen.dart';
import 'notifications_screen.dart';
import 'planner_screen.dart';
import 'review_screen.dart';
import 'rituals_screen.dart';
import 'wellness_screen.dart';

/// HubScreen: Central visual matrix of all secondary domains and utility tools.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  Future<void> _openDomain(BuildContext context, WidgetRef ref, String key, String displayName, Widget screen) async {
    final vaultService = ref.read(vaultServiceProvider);
    final isLocked = await vaultService.isDomainLocked(key);
    if (isLocked && context.mounted) {
      final unlocked = await PinDialog.show(context, vaultService, displayName);
      if (!unlocked) return;
    }

    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hubSections = [
      const _HubItem(
        key: 'planner',
        title: 'Time Blocking',
        subtitle: '24-hour visual agenda & scheduler',
        icon: Icons.calendar_today_rounded,
        color: NeonPalette.cyan,
        screen: PlannerScreen(),
      ),
      const _HubItem(
        key: 'rituals',
        title: 'Rituals & Routines',
        subtitle: 'Morning & evening habit flows',
        icon: Icons.wb_sunny_rounded,
        color: NeonPalette.amber,
        screen: RitualsScreen(),
      ),
      const _HubItem(
        key: 'wellness',
        title: 'Sleep & Energy',
        subtitle: 'Bedtime, wake schedule & vitality',
        icon: Icons.battery_charging_full_rounded,
        color: NeonPalette.mint,
        screen: WellnessScreen(),
      ),
      const _HubItem(
        key: 'journal',
        title: 'Journal & Mood',
        subtitle: 'Daily gratitude, reflections & vibes',
        icon: Icons.edit_note_rounded,
        color: NeonPalette.amber,
        screen: JournalScreen(),
      ),
      const _HubItem(
        key: 'focus',
        title: 'Focus & Pomodoro',
        subtitle: 'Deep work timer & session logger',
        icon: Icons.timer_outlined,
        color: NeonPalette.rose,
        screen: FocusScreen(),
      ),
      const _HubItem(
        key: 'goals',
        title: 'Goals & Horizons',
        subtitle: 'Long-term milestones & OKR targets',
        icon: Icons.flag_rounded,
        color: NeonPalette.blue,
        screen: GoalScreen(),
      ),
      const _HubItem(
        key: 'notes',
        title: 'Markdown Notes',
        subtitle: 'Offline docs, tags & knowledge base',
        icon: Icons.description_outlined,
        color: Color(0xFF38BDF8),
        screen: NotesScreen(),
      ),
      const _HubItem(
        key: 'review',
        title: 'Weekly Review',
        subtitle: 'Sunday retrospective & 3 Big Bets',
        icon: Icons.rate_review_rounded,
        color: NeonPalette.violet,
        screen: ReviewScreen(),
      ),
      const _HubItem(
        key: 'analytics',
        title: 'Trends & Analytics',
        subtitle: 'Interactive charts & heatmaps',
        icon: Icons.analytics_outlined,
        color: NeonPalette.mint,
        screen: AnalyticsScreen(),
      ),
      const _HubItem(
        key: 'notifications',
        title: 'Notifications & Alerts',
        subtitle: 'Scheduled push nudges & cues',
        icon: Icons.notifications_active_outlined,
        color: NeonPalette.cyan,
        screen: NotificationsScreen(),
      ),
      const _HubItem(
        key: 'vault',
        title: 'Private Vault',
        subtitle: 'PIN security & reset controls',
        icon: Icons.lock_outline_rounded,
        color: NeonPalette.rose,
        screen: VaultSettingsScreen(),
      ),
      const _HubItem(
        key: 'export',
        title: 'Export & Backup',
        subtitle: 'Daily Markdown & JSON data dumps',
        icon: Icons.ios_share,
        color: Colors.blueGrey,
        screen: ExportScreen(),
      ),
      const _HubItem(
        key: 'modules',
        title: 'Module Settings',
        subtitle: 'Enable or disable domain modules',
        icon: Icons.tune,
        color: Colors.grey,
        screen: RegistrySettingsScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🧭 Sections & Tools',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemCount: hubSections.length,
        itemBuilder: (context, index) {
          final item = hubSections[index];
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? NeonPalette.borderDark : Colors.grey.shade200,
              ),
              boxShadow: [
                if (isDark)
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (item.screen != null) {
                    _openDomain(context, ref, item.key, item.title, item.screen!);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: item.color.withValues(alpha: 0.3)),
                        ),
                        child: Icon(item.icon, size: 20, color: item.color),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HubItem {
  const _HubItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.screen,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget? screen;
}
