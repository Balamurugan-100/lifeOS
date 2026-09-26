import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/wellness_screen.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('WellnessScreen renders sleep slider, energy ratings, and saves vitals',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final executor = openInMemoryExecutor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
        ],
        child: const MaterialApp(
          home: WellnessScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('🔋 Sleep & Energy Tracker'), findsOneWidget);
    expect(find.text('🌙 Sleep & Wake-up Schedule'), findsOneWidget);
    expect(find.text('Bedtime'), findsOneWidget);
    expect(find.text('Wake-up'), findsOneWidget);
    expect(find.text('⚡ Morning Energy Level'), findsOneWidget);

    // Save vitals
    await tester.tap(find.text('Save Today\'s Vitals'));
    await tester.pumpAndSettle();

    expect(find.text('✨ Sleep & Energy logged for today!'), findsOneWidget);
  });
}
