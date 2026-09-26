import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/quick_capture/command_palette_modal.dart';
import 'package:lifeos_app/security/vault_service.dart';
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

  test('VaultService sets and validates master PIN securely', () async {
    final vault = VaultService();
    expect(await vault.hasPin(), isFalse);
    expect(await vault.isVaultEnabled(), isFalse);

    await vault.setPin('1234');
    expect(await vault.hasPin(), isTrue);
    expect(await vault.isVaultEnabled(), isTrue);

    expect(await vault.verifyPin('1234'), isTrue);
    expect(await vault.verifyPin('9999'), isFalse);

    expect(await vault.isDomainLocked('finance'), isTrue);
    await vault.toggleDomainLock('finance');
    expect(await vault.isDomainLocked('finance'), isFalse);
  });
}
