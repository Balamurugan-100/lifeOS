import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../theme/theme_controller.dart';
import 'home_controller.dart';

/// A single actionable `HighlightedItem` (T026). `complete` items run the
/// direct action in place (SC-007) without leaving home; `openDomain` items
/// navigate to the owning domain.
class HighlightedItemTile extends ConsumerWidget {
  const HighlightedItemTile({
    super.key,
    required this.summary,
    required this.item,
    required this.onOpenDomain,
    required this.onComplete,
    this.accentColor = LifeOSPalette.teal,
  });

  final DomainSummary summary;
  final HighlightedItem item;
  final VoidCallback onOpenDomain;
  final VoidCallback onComplete;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complete = item.action == HighlightAction.complete;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: Key('highlight-${summary.domainKey}-${item.id}'),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? LifeOSPalette.borderDark.withValues(alpha: 0.6)
              : Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (complete) {
              final handled = await performHighlightAction(
                ref,
                summary.domainKey,
                item,
              );
              if (!handled) {
                onOpenDomain();
              } else {
                onComplete();
              }
            } else {
              onOpenDomain();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Leading Icon / Action Trigger
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: complete
                        ? accentColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: complete
                          ? accentColor.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    complete
                        ? Icons.radio_button_unchecked
                        : Icons.arrow_outward_rounded,
                    size: 15,
                    color: complete
                        ? accentColor
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Trailing Action indicator
                Icon(
                  complete
                      ? Icons.check_circle_outline_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: complete
                      ? accentColor.withValues(alpha: 0.7)
                      : (isDark ? Colors.white38 : Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}