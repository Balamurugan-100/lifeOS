import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/review_screen.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('ReviewScreen renders performance metrics, questions, and saves retrospective',
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
          home: ReviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('📅 Weekly Review & Protocol'), findsOneWidget);
    expect(find.text('⭐ Rate Your Week'), findsOneWidget);
    expect(find.text('🏆 Wins & Lessons'), findsOneWidget);
    expect(find.text('🎯 Next Week\'s 3 Big Bets'), findsOneWidget);

    // Save Retrospective
    await tester.tap(find.text('Save Weekly Retrospective'));
    await tester.pumpAndSettle();

    expect(find.text('🏆 Weekly Retrospective & Intentions Saved!'), findsOneWidget);
  });
}
