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
      'tasks' => LifeOSPalette.teal,
      'habits' => LifeOSPalette.sage,
      'finance' => LifeOSPalette.clay,
      _ => LifeOSPalette.slate,
    };
  }

  IconData _getDomainIcon(String domainKey) {
    return switch (domainKey) {
      'tasks' => Icons.checklist_rounded,
      'habits' => Icons.local_fire_department_rounded,
      'finance' => Icons.account_balance_wallet_rounded,
      _ => Icons.dashboard_outlined,
    };
  }

  /// Human-readable labels for the summary count keys each domain publishes,
  /// so the pills never leak internal names like `trackedSeconds`.
  static String _countLabel(String key) {
    return switch (key) {
      'outstanding' => 'outstanding',
      'overdue' => 'overdue',
      'completedToday' => 'done today',
      'doneToday' => 'done today',
      'trackedMinutes' => 'min tracked',
      'trackedSeconds' => 'sec tracked',
      'active' => 'active',
      'accounts' => 'accounts',
      'dueToday' => 'due today',
      _ => key,
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? LifeOSPalette.borderDark.withValues(alpha: 0.7)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDark ? LifeOSPalette.surfaceCard : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: accentColor,
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with inline counts
              InkWell(
                onTap: onOpenDomain,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(domainIcon, size: 16, color: accentColor),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        summary.displayName,
                        key: Key('open-${summary.domainKey}'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Inline count pills
                      if (counts.isNotEmpty)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final entry in counts)
                                  Container(
                                    key: Key('count-${summary.domainKey}-${entry.key}'),
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: accentColor.withValues(alpha: 0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                     child: Text(
                                       '${entry.value} ${_countLabel(entry.key)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ],
                  ),
                ),
              ),

              // Highlighted Action Items (if any)
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