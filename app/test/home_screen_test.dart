import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/bootstrap/registry.dart';
import 'package:lifeos_app/home/home_controller.dart';
import 'package:lifeos_app/navigation/finance_screen.dart';
import 'package:lifeos_app/navigation/habit_screen.dart';
import 'package:lifeos_app/navigation/task_screen.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

DomainSummary _tasksSummary({
  List<HighlightedItem> highlighted = const [],
  Map<String, int> counts = const {'outstanding': 2, 'overdue': 1},
}) =>
    DomainSummary(
      domainKey: 'tasks',
      displayName: 'Tasks',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );

DomainSummary _habitsSummary() => DomainSummary(
      domainKey: 'habits',
      displayName: 'Habits',
      counts: const {'doneToday': 1},
      highlighted: const [],
      refreshedAt: DateTime(2026, 9, 22),
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

  @override
  final String key;
  @override
  final String name;
  final List<DomainSummary> Function()? summaries;
  int buildCount = 0;
  final List<HighlightedItem> handled = [];

  @override
  Future<DomainSummary> buildSummary() async {
    buildCount++;
    final provided = summaries?.call() ?? const <DomainSummary>[];
    if (provided.isEmpty) {
      return DomainSummary(
        domainKey: key,
        displayName: name,
        counts: const {},
        highlighted: const [],
        refreshedAt: DateTime.now().toUtc(),
      );
    }
    return provided.first;
  }

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    handled.add(item);
    return item.action == HighlightAction.complete;
  }
}

Widget _app({
  QueryExecutor? executor,
  ModuleRegistry? registry,
  List<DomainSummary>? summaries,
}) {
  return ProviderScope(
    overrides: [
      databaseExecutorProvider
          .overrideWith((ref) async => executor ?? openInMemoryExecutor()),
      if (registry != null)
        moduleRegistryProvider.overrideWith((ref) async => registry),
      if (summaries != null)
        summariesProvider.overrideWith((ref) async => summaries),
    ],
    child: const LifeOSApp(),
  );
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('T020: home shows empty state when no domain has data (FR-004)',
      (tester) async {
    _usePhoneSize(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emptystate')), findsOneWidget);
    expect(find.byKey(const Key('openTasks')), findsOneWidget);
    expect(find.byKey(const Key('openHabits')), findsOneWidget);
    expect(find.byKey(const Key('openFinance')), findsOneWidget);
    expect(find.text('Your LifeOS is ready'), findsOneWidget);
  });

  testWidgets(
      'T021: summary cards render from DomainSummary fixtures (FR-001, FR-007)',
      (tester) async {
    _usePhoneSize(tester);

    await tester.pumpWidget(_app(summaries: [
      _tasksSummary(highlighted: const [_overdueItem]),
      _habitsSummary(),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
    expect(find.byKey(const Key('summary-habits')), findsOneWidget);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('2 outstanding'), findsOneWidget);
    expect(find.text('1 overdue'), findsOneWidget);
    // Count pills are labelled for humans, not by internal key.
    expect(find.text('1 done today'), findsOneWidget);
    expect(find.text('1 doneToday'), findsNothing);
    expect(find.text('Fix the bug'), findsOneWidget);
    expect(find.text('Due 2026-09-20'), findsOneWidget);
  });

  testWidgets(
      'T022: highlighted complete action runs without leaving home (SC-007)',
      (tester) async {
    _usePhoneSize(tester);

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
    _usePhoneSize(tester);

    final fake = _FakeModule('tasks', 'Tasks',
        summaries: () => [_tasksSummary(highlighted: const [_overdueItem])]);
    final registry = ModuleRegistry()..register(fake);

    await tester.pumpWidget(_app(registry: registry));
    await tester.pumpAndSettle();
    final before = fake.buildCount;

    // Push a route off home, then come back: `didPopNext` must re-ask the
    // registry for summaries.
    await tester.tap(find.byKey(const Key('openExport')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskScreen), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(fake.buildCount, greaterThan(before));
  });

  testWidgets('T024: tracked time today is surfaced on the home overview',
      (tester) async {
    _usePhoneSize(tester);

    await tester.pumpWidget(_app(summaries: [
      _tasksSummary(counts: const {
        'outstanding': 2,
        'overdue': 1,
        'trackedMinutes': 45,
        'trackedSessions': 3,
      }),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-time-card')), findsOneWidget);
    expect(find.text('Tracked today'), findsOneWidget);
    expect(find.text('45 min across 3 sessions'), findsOneWidget);
    // The same figures also appear as a labelled count pill on the card.
    expect(find.text('45 min tracked'), findsOneWidget);
  });

  testWidgets('T025: no tracked time reads as an invitation, not a zero',
      (tester) async {
    _usePhoneSize(tester);

    await tester.pumpWidget(_app(summaries: [_tasksSummary()]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-time-value')), findsOneWidget);
    expect(find.text('No time logged yet'), findsOneWidget);
  });

  testWidgets('T026: bottom bar switches between the three core domains',
      (tester) async {
    _usePhoneSize(tester);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emptystate')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-tasks')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-habits')));
    await tester.pumpAndSettle();
    expect(find.byType(HabitScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-finance')));
    await tester.pumpAndSettle();
    expect(find.byType(FinanceScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptystate')), findsOneWidget);
  });

  testWidgets('T027: tapping a summary card switches to that domain tab',
      (tester) async {
    _usePhoneSize(tester);

    await tester.pumpWidget(_app(summaries: [
      _tasksSummary(highlighted: const [_overdueItem]),
      _habitsSummary(),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-habits')));
    await tester.pumpAndSettle();

    // The card hands off to the tab, it does not push a route — so home keeps
    // its place in the bottom bar and no back button is introduced.
    expect(find.byType(HabitScreen), findsOneWidget);
    expect(find.byType(TaskScreen), findsNothing);

    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-tasks')), findsOneWidget);
  });
}
