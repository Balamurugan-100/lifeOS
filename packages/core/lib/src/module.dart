/// The domain-module contract (contracts/domain-module-contract.md).
///
/// A `ModuleDescriptor` is the entire surface a domain exposes to the rest
/// of the system. Domains never see the registry or each other (constitution
/// Principle I, FR-006, FR-012).
library;

import 'summary.dart';

/// What every domain package must implement to be registered.
abstract class ModuleDescriptor {
  /// Permanent, stable key (never renamed), e.g. `tasks`.
  String get key;

  /// Human-readable module name, e.g. "Tasks".
  String get name;

  /// Builds the current [DomainSummary] for the home overview.
  Future<DomainSummary> buildSummary();

  /// Handles a direct home action (e.g. `complete`) for this domain.
  ///
  /// Returns true when the action was consumed successfully. Unknown kinds
  /// return false so the caller can fall back to opening the domain.
  Future<bool> handleAction(HighlightedItem item);
}