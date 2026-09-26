import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/planner_screen.dart';
import 'package:lifeos_planner/lifeos_planner.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

void main() {
  testWidgets('PlannerScreen renders day timeline and displays scheduled time blocks',
      (tester) async {
    final executor = openInMemoryExecutor();
    final db = PlannerDatabase(executor);
    await db.ensureTables();
    final repo = PlannerRepository(db);

    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await repo.createBlock(
      title: 'Deep Architecture Focus',
      date: today,
      startMinute: 540,
      durationMinutes: 90,
      category: BlockCategory.focus,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
          plannerRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: const MaterialApp(
          home: PlannerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('⏰ Time Blocking Blueprint'), findsOneWidget);
    expect(find.text('Deep Architecture Focus'), findsOneWidget);
    expect(find.text('FOCUS'), findsOneWidget);
  });
}
