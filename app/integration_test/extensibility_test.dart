import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_habits/lifeos_habits.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

import 'helpers.dart';

/// US5 extensibility (T062, FR-006, SC-003): registering a third, throwaway
/// module requires zero changes to existing domain packages and its summary
/// appears on home automatically.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a newly registered module appears on home without touching '
      'existing domains', (tester) async {
    final registry = ModuleRegistry()
      ..register(TasksModule(TaskDatabase(openInMemoryExecutor())))
      ..register(HabitsModule(HabitDatabase(openInMemoryExecutor())))
      ..register(FakeModule(
        'pleasures',
        'Pleasures',
        () => [
          DomainSummary(
            domainKey: 'pleasures',
            displayName: 'Pleasures',
            counts: const {'today': 3},
            highlighted: const [],
            refreshedAt: DateTime.now().toUtc(),
          ),
        ],
      ));

    await pumpLifeOSApp(tester, registry: registry);

    expect(find.byKey(const Key('summary-pleasures')), findsOneWidget);
    expect(find.text('Pleasures'), findsWidgets);
    expect(find.text('3 today'), findsOneWidget);
    // The existing domains are registered too, but have no data yet.
    expect(find.byKey(const Key('summary-tasks')), findsNothing);
    expect(find.byKey(const Key('summary-habits')), findsNothing);
  });
}