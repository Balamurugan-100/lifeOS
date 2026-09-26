import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../theme/theme_controller.dart';
import 'highlighted_section.dart';

/// One domain's card on the home overview (T025): name, semantic counts, and
/// up to three actionable items. The home is a consumer of DomainSummary —
/// it never talks to domains directly (FR-012).
class SummarySection extends ConsumerWidget {
  const SummarySection({
    super.key,
    required this.summary,
    required this.onOpenDomain,
    required this.onItemComplete,
  });

  final DomainSummary summary;
  final VoidCallback onOpenDomain;
  final void Function(HighlightedItem item) onItemComplete;

  Color _getDomainColor(String domainKey) {
    return switch (domainKey) {
      'tasks' => NeonPalette.cyan,
      'habits' => NeonPalette.mint,
      'finance' => NeonPalette.violet,
      'journal' => NeonPalette.amber,
      'focus' => NeonPalette.rose,
      'goals' => NeonPalette.blue,
      'notes' => const Color(0xFF38BDF8),
      'gamification' => NeonPalette.violet,
      'rituals' => NeonPalette.amber,
      'planner' => NeonPalette.cyan,
      'wellness' => NeonPalette.mint,
      'review' => NeonPalette.violet,
      _ => NeonPalette.blue,
    };
  }

  IconData _getDomainIcon(String domainKey) {
    return switch (domainKey) {
      'tasks' => Icons.checklist_rounded,
      'habits' => Icons.local_fire_department_rounded,
      'finance' => Icons.account_balance_wallet_rounded,
      'journal' => Icons.edit_note_rounded,
      'focus' => Icons.timer_outlined,
      'goals' => Icons.flag_rounded,
      'notes' => Icons.description_outlined,
      'gamification' => Icons.military_tech_rounded,
      'rituals' => Icons.wb_sunny_rounded,
      'planner' => Icons.calendar_month_rounded,
      'wellness' => Icons.battery_charging_full_rounded,
      'review' => Icons.rate_review_rounded,
      _ => Icons.dashboard_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = _getDomainColor(summary.domainKey);
    final domainIcon = _getDomainIcon(summary.domainKey);

    final counts = summary.counts.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      key: Key('summary-${summary.domainKey}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? NeonPalette.borderDark
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDark ? NeonPalette.surfaceCard : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: accentColor.withValues(alpha: 0.9),
              width: 4,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              InkWell(
                onTap: onOpenDomain,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(domainIcon, size: 18, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        summary.displayName,
                        key: Key('open-${summary.domainKey}'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Semantic Counts
              if (counts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final entry in counts)
                      Container(
                        key: Key('count-${summary.domainKey}-${entry.key}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '${entry.value} ${entry.key}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // Highlighted Action Items
              if (summary.highlighted.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...summary.highlighted.take(3).map(
                      (item) => HighlightedItemTile(
                        summary: summary,
                        item: item,
                        accentColor: accentColor,
                        onOpenDomain: onOpenDomain,
                        onComplete: () => onItemComplete(item),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}