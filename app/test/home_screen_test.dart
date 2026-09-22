import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/bootstrap/registry.dart';
import 'package:lifeos_app/home/home_controller.dart';
import 'package:lifeos_app/navigation/task_screen.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

DomainSummary _tasksSummary({
  List<HighlightedItem> highlighted = const [],
}) =>
    DomainSummary(
      domainKey: 'tasks',
      displayName: 'Tasks',
      counts: const {'outstanding': 2, 'overdue': 1},
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );

const _overdueItem = HighlightedItem(
  id: 't1',
  kind: 'task.overdue',
  title: 'Fix the bug',
  subtitle: 'Due 2026-09-20',
  action: HighlightAction.complete,
);

class _FakeModule extends ModuleDescriptor {
  _FakeModule(this.key, this.name, {this.summaries});

  final String key;
  final String name;
  final List<DomainSummary> Function()? summaries;
  int buildCount = 0;
  final List<HighlightedItem> handled = [];

  @override
  Future<DomainSummary> buildSummary() async {
    buildCount++;
    return summaries?.call() ??
        DomainSummary(
          domainKey: key,
          displayName: name,
          counts: const {},
          highlighted: const [],
          refreshedAt: DateTime.now().toUtc(),
        );
  }

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    handled.add(item);
    return item.action == HighlightAction.complete;
  }
}

Widget _app({QueryExecutor? executor, ModuleRegistry? registry, List<DomainSummary>? summaries}) {
  return ProviderScope(
    overrides: [
      databaseExecutorProvider.overrideWithValue(executor ?? openInMemoryExecutor()),
      if (registry != null) moduleRegistryProvider.overrideWithValue(registry),
      if (summaries != null)
        summariesProvider.overrideWith((ref) async => summaries),
    ],
    child: const LifeOSApp(),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('T020: home shows empty state when no domain has data (FR-004)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emptystate')), findsOneWidget);
    expect(find.byKey(const Key('openTasks')), findsOneWidget);
    expect(find.byKey(const Key('openHabits')), findsOneWidget);
    expect(find.text('Your LifeOS is ready'), findsOneWidget);
  });

  testWidgets(
      'T021: summary cards render from DomainSummary fixtures (FR-001, FR-007)',
      (tester) async {
    await tester.pumpWidget(_app(summaries: [
      _tasksSummary(highlighted: const [_overdueItem]),
      DomainSummary(
        domainKey: 'habits',
        displayName: 'Habits',
        counts: const {'doneToday': 1},
        highlighted: const [],
        refreshedAt: DateTime(2026, 9, 22),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('2 outstanding'), findsOneWidget);
    expect(find.text('1 overdue'), findsOneWidget);
    expect(find.text('1 doneToday'), findsOneWidget);
    expect(find.text('Fix the bug'), findsOneWidget);
    expect(find.text('Due 2026-09-20'), findsOneWidget);
  });

  testWidgets(
      'T022: highlighted complete action runs without leaving home (SC-007)',
      (tester) async {
    final fake = _FakeModule('tasks', 'Tasks',
        summaries: () => [_tasksSummary(highlighted: const [_overdueItem])]);
    final registry = ModuleRegistry()..register(fake);

    await tester.pumpWidget(_app(
      registry: registry,
      summaries: [_tasksSummary(highlighted: const [_overdueItem])],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('highlight-tasks-t1')));
    await tester.pumpAndSettle();

    expect(fake.handled.single.id, 't1');
    expect(find.byType(TaskScreen), findsNothing); // stayed on home
    expect(find.byKey(const Key('emptystate')), findsNothing);
  });

  testWidgets('T023: home refreshes on return to home (FR-003, SC-002)',
      (tester) async {
    final fake = _FakeModule('tasks', 'Tasks',
        summaries: () => [_tasksSummary(highlighted: const [_overdueItem])]);
    final registry = ModuleRegistry()..register(fake);

    await tester.pumpWidget(_app(registry: registry));
    await tester.pumpAndSettle();
    final before = fake.buildCount;

    await tester.tap(find.byKey(const Key('open-tasks')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(fake.buildCount, greaterThan(before));
  });
}