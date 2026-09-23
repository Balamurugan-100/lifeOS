import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart';

import '../bootstrap/registry.dart';

/// Summaries of every enabled module, in registry order (FR-001).
///
/// Recomputed on every return to home: consumers invalidate this provider and
/// the registry rebuilds each summary from live data (FR-003, SC-002).
final summariesProvider = FutureProvider<List<DomainSummary>>((ref) async {
  final registry = await ref.watch(moduleRegistryProvider.future);
  return registry.buildSummaries();
});

/// Runs a direct home action (e.g. `complete`) through the owning module
/// (SC-007) and refreshes the overview when the action was consumed.
Future<bool> performHighlightAction(
  WidgetRef ref,
  String domainKey,
  HighlightedItem item,
) async {
  final registry = await ref.read(moduleRegistryProvider.future);
  final handled = await registry.handleAction(domainKey, item);
  if (handled) {
    ref.invalidate(summariesProvider);
  }
  return handled;
}

/// Re-fetch summaries after any mutating flow (used by domain screens).
Future<void> refreshSummaries(WidgetRef ref) async {
  ref.invalidate(summariesProvider);
  await ref.read(summariesProvider.future);
}