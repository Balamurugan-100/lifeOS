import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/bootstrap/registry.dart';
import 'package:lifeos_app/home/home_controller.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('debug T020 state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseExecutorProvider
            .overrideWith((ref) async => openInMemoryExecutor()),
      ],
      child: const LifeOSApp(),
    ));
    await tester.pumpAndSettle();

    final err = find.textContaining('Could not load');
    if (tester.any(err)) {
      debugPrint('ERROR UI: ${(tester.widget(err) as Text).data}');
    }
    debugPrint('emptystate=${tester.any(find.byKey(const Key("emptystate")))}');
    debugPrint('spinner=${tester.any(find.byType(CircularProgressIndicator))}');
    final summaries = await tester
        .element(find.byType(LifeOSApp))
        .read(summariesProvider.future)
        .then((v) => v)
        .catchError((Object e) => 'ERR: $e');
    debugPrint('summaries=$summaries');
  });
}
