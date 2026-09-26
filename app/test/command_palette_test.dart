import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/quick_capture/command_palette_modal.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:lifeos_tasks/lifeos_tasks.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Command Palette captures new tasks directly into SQLite',
      (tester) async {
    final executor = openInMemoryExecutor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CommandPaletteModal(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('QUICK COMMAND PALETTE'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);

    // Type natural language command
    await tester.enterText(find.byType(TextField), 'Fix the iOS issue by today @ios !urgent');
    await tester.pumpAndSettle();

    // Verify live preview badges appear
    expect(find.text('Due: Today'), findsOneWidget);
    expect(find.text('@ios'), findsOneWidget);
    expect(find.text('P1 Urgent'), findsOneWidget);
    expect(find.text('Title: "Fix the iOS issue"'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final taskRepo = await container.read(taskRepositoryProvider.future);
    final allTasks = await taskRepo.all();
    expect(allTasks.length, 1);
    expect(allTasks.first.title, 'Fix the iOS issue');
    expect(allTasks.first.category, 'ios');
    expect(allTasks.first.priority, TaskPriority.urgent);
    expect(allTasks.first.dueDate, isNotNull);
  });

  testWidgets('Command Palette time mode starts a session on a matching task',
      (tester) async {
    final executor = openInMemoryExecutor();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CommandPaletteModal(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track Time'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Write the release notes @pomo');
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final taskRepo = await container.read(taskRepositoryProvider.future);
    final timeRepo = await container.read(timeRepositoryProvider.future);

    // The task did not exist yet, so the palette created it...
    final tasks = await taskRepo.all();
    expect(tasks.length, 1);
    expect(tasks.first.title, 'Write the release notes');

    // ...and started a pomodoro-tagged session against it.
    final active = await timeRepo.activeSession();
    expect(active, isNotNull);
    expect(active!.taskId, tasks.first.id);
    expect(active.isPomodoro, isTrue);
  });

  testWidgets('Command Palette time mode resolves an existing task by tag',
      (tester) async {
    final executor = openInMemoryExecutor();
    final container = ProviderContainer(overrides: [
      databaseExecutorProvider.overrideWith((ref) async => executor),
    ]);
    addTearDown(container.dispose);
    final taskRepo = await container.read(taskRepositoryProvider.future);
    final existing = await taskRepo.add('Ship the release', category: 'release');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseExecutorProvider.overrideWith((ref) async => executor),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CommandPaletteModal(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track Time'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'polish the changelog @release');
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final timeRepo = await container.read(timeRepositoryProvider.future);
    final active = await timeRepo.activeSession();

    // The @release tag matched the existing task instead of creating a new one.
    expect((await taskRepo.all()).length, 1);
    expect(active, isNotNull);
    expect(active!.taskId, existing.id);
    expect(active.isPomodoro, isFalse);
    expect(active.label, 'polish the changelog');
  });
}
