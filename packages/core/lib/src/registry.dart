/// Module lifecycle and aggregation (contracts/domain-module-contract.md,
/// FR-005, FR-006).
///
/// The app shell owns a [ModuleRegistry]; consumers (Home) see summaries of
/// enabled modules only. Domain packages never import this file.
library;

import 'module.dart';
import 'summary.dart';

/// Loads previously persisted enable/disable state (maps module key to
/// enabled flag). The app's settings storage implements this; out of the box
/// every module defaults to enabled.
typedef EnabledStateStore = Future<Map<String, bool>> Function();

/// Persists a single enable/disable decision made via [ModuleRegistry.setEnabled].
typedef EnabledStateWriter = Future<void> Function(String key, bool enabled);

/// Collects domain descriptors and exposes only enabled modules.
///
/// Persisting enable/disable state (FR-005) is delegated to the app via
/// [loadState] / [persistState] so this package stays storage-agnostic and
/// works the same in tests.
class ModuleRegistry {
  ModuleRegistry({EnabledStateStore? loadState, EnabledStateWriter? persistState})
      : _loadState = loadState,
        _persistState = persistState;

  final EnabledStateStore? _loadState;
  final EnabledStateWriter? _persistState;

  final Map<String, ModuleDescriptor> _modules = {};
  final Map<String, bool> _enabled = {};
  bool _stateLoaded = false;

  /// Registers a module descriptor. Adding a module never touches existing
  /// modules (FR-006).
  void register(ModuleDescriptor module) {
    _modules[module.key] = module;
    _enabled[module.key] = _enabled[module.key] ?? true;
  }

  /// Restores persisted enable/disable state (call once after all
  /// registrations; no-op when no [loadState] was provided).
  Future<void> loadState() async {
    if (_stateLoaded || _loadState == null) return;
    final state = await _loadState();
    state.forEach((key, enabled) {
      if (_enabled.containsKey(key)) _enabled[key] = enabled;
    });
    _stateLoaded = true;
  }

  /// All known modules, in registration order.
  List<ModuleDescriptor> get allModules => _modules.values.toList(growable: false);

  bool isEnabled(String key) => _enabled[key] ?? false;

  /// Modules that currently contribute to the home overview.
  List<ModuleDescriptor> enabledModules() =>
      allModules.where((m) => isEnabled(m.key)).toList(growable: false);

  /// Enables or disables [key] without touching any other module's data
  /// (FR-005). Disabling retains the module's data; re-enabling restores it
  /// exactly (SC-003).
  Future<void> setEnabled(String key, bool enabled) async {
    if (!_modules.containsKey(key)) return;
    _enabled[key] = enabled;
    await _persistState?.call(key, enabled);
  }

  /// Summaries for every enabled module, in registration order (FR-001).
  Future<List<DomainSummary>> buildSummaries() async {
    final summaries = <DomainSummary>[];
    for (final module in enabledModules()) {
      summaries.add(await module.buildSummary());
    }
    return summaries;
  }

  /// Routes a direct home action to the owning enabled module (SC-007).
  Future<bool> handleAction(String domainKey, HighlightedItem item) async {
    final module = _modules[domainKey];
    if (module == null || !isEnabled(domainKey)) return false;
    return module.handleAction(item);
  }
}