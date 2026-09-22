import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

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
  });

  final DomainSummary summary;
  final HighlightedItem item;
  final VoidCallback onOpenDomain;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complete = item.action == HighlightAction.complete;
    return ListTile(
      key: Key('highlight-${summary.domainKey}-${item.id}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        complete ? Icons.radio_button_unchecked : Icons.launch,
        size: 20,
        color: complete
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: item.subtitle == null ? null : Text(item.subtitle!),
      trailing: Icon(
        complete ? Icons.check_circle_outline : Icons.chevron_right,
        size: 20,
      ),
      onTap: () async {
        if (complete) {
          final handled = await performHighlightAction(
            ref,
            summary.domainKey,
            item,
          );
          if (!handled) onOpenDomain();
        } else {
          onOpenDomain();
        }
      },
    );
  }
}