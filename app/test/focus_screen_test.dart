import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/focus_screen.dart';
import 'package:lifeos_focus/lifeos_focus.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';

void main() {
  testWidgets('Focus screen renders timer, switches modes, and starts timer',
      (tester) async {
    final focusDb = FocusDatabase(openInMemoryExecutor());
    await focusDb.ensureTables();
    final taskDb = TaskDatabase(openInMemoryExecutor());
    await taskDb.ensureTables();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusDatabaseProvider.overrideWith((ref) async => focusDb),
          taskDatabaseProvider.overrideWith((ref) async => taskDb),
        ],
        child: const MaterialApp(
          home: FocusScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Focus & Pomodoro'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    // Switch to 50m Deep Work
    await tester.tap(find.byKey(const Key('focus_mode_deepWork')));
    await tester.pumpAndSettle();

    expect(find.text('50:00'), findsOneWidget);

    // Start timer
    await tester.tap(find.byKey(const Key('toggleTimerButton')));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Pause'), findsOneWidget);

    // Pause timer
    await tester.tap(find.byKey(const Key('toggleTimerButton')));
    await tester.pumpAndSettle();

    expect(find.text('Start Focus'), findsOneWidget);
  });
}
