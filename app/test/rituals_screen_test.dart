import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/rituals_screen.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('RitualsScreen renders default morning & evening rituals and toggles steps',
      (tester) async {
    final executor = openInMemoryExecutor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
        ],
        child: const MaterialApp(
          home: RitualsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('🌅 Rituals & Routines'), findsOneWidget);
    expect(find.text('Morning Kickstart Ritual'), findsOneWidget);
    expect(find.text('Evening Shutdown & Wind-down'), findsOneWidget);

    // Toggle step
    await tester.tap(find.text('Hydrate (500ml) & Quick Stretch'));
    await tester.pumpAndSettle();
  });
}
