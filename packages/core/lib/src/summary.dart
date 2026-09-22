/// The home-overview contract (contracts/domain-summary-contract.md).
///
/// Every enabled domain produces a [DomainSummary] that the home experience
/// renders. Domains know nothing about the home; the home knows only this
/// shape (constitution Principle I, FR-012).
library;

/// What tapping a highlighted item should do.
enum HighlightAction { complete, openDomain }

/// A single actionable entry inside a [DomainSummary].
class HighlightedItem {
  const HighlightedItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    required this.action,
  });

  /// Stable reference to the underlying item (task/habit id).
  final String id;

  /// Semantic kind, e.g. `task.due`, `task.overdue`, `habit.today`.
  final String kind;

  /// Short display text.
  final String title;

  /// Optional context (due date, streak, ...).
  final String? subtitle;

  /// What a tap does; `complete` only when a direct action is safe (SC-007).
  final HighlightAction action;

  @override
  bool operator ==(Object other) =>
      other is HighlightedItem &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.action == action;

  @override
  int get hashCode => Object.hash(id, kind, title, subtitle, action);

  @override
  String toString() =>
      'HighlightedItem($kind: $title${subtitle == null ? '' : ' ($subtitle)'})';
}

/// The per-domain summary shown on the home overview (FR-001, FR-007).
class DomainSummary {
  const DomainSummary({
    required this.domainKey,
    required this.displayName,
    required this.counts,
    required this.highlighted,
    required this.refreshedAt,
  });

  /// Stable module key, e.g. `tasks`, `habits`.
  final String domainKey;

  /// Human-readable module name, e.g. "Tasks".
  final String displayName;

  /// Semantic counts; keys are stable per domain (e.g. tasks:
  /// `outstanding`, `overdue`, `completedToday`).
  final Map<String, int> counts;

  /// Priority-ordered actionable items, capped by the home UI (default 3).
  final List<HighlightedItem> highlighted;

  /// When the summary was computed (UTC).
  final DateTime refreshedAt;

  /// True when the domain has nothing to show on home (FR-004 empty state).
  bool get isEmpty =>
      highlighted.isEmpty && counts.values.every((count) => count == 0);

  @override
  String toString() => 'DomainSummary($domainKey: $counts)';
}