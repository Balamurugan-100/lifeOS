import 'package:lifeos_core/lifeos_core.dart';
import 'package:test/test.dart';

class _FakeModule extends ModuleDescriptor {
  _FakeModule(this.key, this.name, {this.summaryCounts = const {}});

  @override
  final String key;

  @override
  final String name;

  final Map<String, int> summaryCounts;

  @override
  Future<DomainSummary> buildSummary() async => DomainSummary(
        domainKey: key,
        displayName: name,
        counts: summaryCounts,
        highlighted: const [],
        refreshedAt: DateTime.utc(2026, 9, 22),
      );

  @override
  Future<bool> handleAction(HighlightedItem item) async => item.kind == 'ok';
}

void main() {
  group('ModuleRegistry', () {
    test('registers modules and reports enabled state', () {
      final registry = ModuleRegistry()
        ..register(_FakeModule('tasks', 'Tasks'))
        ..register(_FakeModule('habits', 'Habits'));
      expect(registry.allModules.length, 2);
      expect(registry.isEnabled('tasks'), isTrue);
      expect(registry.enabledModules().length, 2);
    });

    test('setEnabled persists via writer and excludes disabled from home', () async {
      final writes = <String>{};
      final registry = ModuleRegistry(
        persistState: (key, enabled) async => writes.add(key),
      )
        ..register(_FakeModule('a', 'A', summaryCounts: {'x': 3}))
        ..register(_FakeModule('b', 'B'));

      await registry.setEnabled('a', false);

      expect(writes, contains('a'));
      expect(registry.isEnabled('a'), isFalse);
      final summaries = await registry.buildSummaries();
      expect(summaries.map((s) => s.domainKey), ['b']);
    });

    test('loadState restores persisted enable/disable state (FR-005)', () async {
      final registry = ModuleRegistry(
        loadState: () async => {'a': false},
      )
        ..register(_FakeModule('a', 'A'))
        ..register(_FakeModule('b', 'B'));

      await registry.loadState();
      expect(registry.isEnabled('a'), isFalse);
      expect(registry.isEnabled('b'), isTrue);
      final summaries = await registry.buildSummaries();
      expect(summaries.map((s) => s.domainKey), ['b']);
    });

    test('handleAction routes only to enabled owning module (SC-007)', () async {
      final registry = ModuleRegistry()
        ..register(_FakeModule('a', 'A'));
      expect(
        await registry.handleAction('a', const HighlightedItem(
          id: 'x',
          kind: 'ok',
          title: 't',
          action: HighlightAction.complete,
        )),
        isTrue,
      );
      expect(
        await registry.handleAction('a', const HighlightedItem(
          id: 'x',
          kind: 'other',
          title: 't',
          action: HighlightAction.complete,
        )),
        isFalse,
      );
      expect(
        await registry.handleAction('missing', const HighlightedItem(
          id: 'x',
          kind: 'ok',
          title: 't',
          action: HighlightAction.complete,
        )),
        isFalse,
      );
    });
  });

  group('DomainSummary', () {
    test('isEmpty is true only when nothing to show (FR-004)', () {
      DomainSummary empty() => DomainSummary(
            domainKey: 't',
            displayName: 'T',
            counts: const {},
            highlighted: const [],
            refreshedAt: DateTime.utc(2026, 9, 22),
          );
      expect(empty().isEmpty, isTrue);
    });
  });
}