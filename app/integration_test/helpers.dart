import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/bootstrap/registry.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the real app with a configurable backing executor and registry.
///
/// Tests override the file-backed database with [executor]
/// (in-memory unless given); the module registry is either the real one
/// (built from then-empty/real databases) or a supplied [registry].
Future<void> pumpLifeOSApp(
  WidgetTester tester, {
  QueryExecutor? executor,
  ModuleRegistry? registry,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseExecutorProvider
            .overrideWith((ref) async => executor ?? openInMemoryExecutor()),
        if (registry != null)
          moduleRegistryProvider.overrideWith((ref) async => registry),
      ],
      child: const LifeOSApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A third-party module used by the extensibility test (T062) — registered
/// only from the app side, never touching domain packages.
class FakeModule extends ModuleDescriptor {
  FakeModule(this.key, this.name, this.summaries);

  @override
  final String key;
  @override
  final String name;
  final List<DomainSummary> Function() summaries;

  @override
  Future<DomainSummary> buildSummary() async => summaries().first;

  @override
  Future<bool> handleAction(HighlightedItem item) async => false;
}