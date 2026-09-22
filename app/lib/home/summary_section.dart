import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final counts = summary.counts.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      key: Key('summary-${summary.domainKey}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: Key('open-${summary.domainKey}'),
                    onTap: onOpenDomain,
                    child: Text(
                      summary.displayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Open ${summary.displayName}',
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: onOpenDomain,
                ),
              ],
            ),
            if (counts.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in counts)
                    Chip(
                      key: Key('count-${summary.domainKey}-${entry.key}'),
                      label: Text('${entry.value} ${entry.key}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ...summary.highlighted.take(3).map(
                  (item) => HighlightedItemTile(
                    summary: summary,
                    item: item,
                    onOpenDomain: onOpenDomain,
                    onComplete: () => onItemComplete(item),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}