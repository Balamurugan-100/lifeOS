import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/gamification_screen.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('Gamification screen renders profile, switches tabs, and shows quests',
      (tester) async {
    final executor = openInMemoryExecutor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
        ],
        child: const MaterialApp(
          home: GamificationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and level card
    expect(find.text('🎮 LifeXP & Mastery'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('DAILY BOUNTIES & QUESTS'), findsOneWidget);

    // Switch to Life Radar tab
    await tester.tap(find.text('Life Radar'));
    await tester.pumpAndSettle();

    expect(find.text('Life Balance Equilibrium'), findsOneWidget);
    expect(find.text('⚡ Productivity (Tasks & Focus)'), findsOneWidget);

    // Switch to Badges tab
    await tester.tap(find.text('Badges'));
    await tester.pumpAndSettle();

    expect(find.text('First Step'), findsOneWidget);
  });
}
