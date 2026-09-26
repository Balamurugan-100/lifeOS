import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/rituals_screen.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('RitualsScreen starts empty without mandatory defaults and supports adding, checking and deleting',
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
    expect(find.text('No rituals configured yet'), findsOneWidget);

    // Tap Add ritual
    await tester.tap(find.byKey(const Key('create-first-ritual-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create Custom Ritual'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ritual-name-input')), 'My Morning Routine');
    await tester.tap(find.byKey(const Key('save-ritual-button')));
    await tester.pumpAndSettle();

    // Verify ritual was created
    expect(find.text('My Morning Routine'), findsOneWidget);
    expect(find.text('Hydrate & Stretch'), findsOneWidget);

    // Toggle step
    await tester.tap(find.text('Hydrate & Stretch'));
    await tester.pumpAndSettle();

    // Delete ritual
    final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButtons, findsOneWidget);
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Delete Ritual?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify empty state is restored
    expect(find.text('No rituals configured yet'), findsOneWidget);
  });
}
