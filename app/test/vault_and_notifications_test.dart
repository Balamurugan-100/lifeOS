import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/navigation/notifications_screen.dart';
import 'package:lifeos_app/security/vault_settings_screen.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('VaultSettingsScreen explains defaults, sets PIN, and allows resetting vault',
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
          home: VaultSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('🔐 Private Vault'), findsOneWidget);
    expect(find.text('Vault Unlocked'), findsOneWidget);
    expect(find.text('What is the Default Vault Setting?'), findsOneWidget);

    // Set PIN
    await tester.tap(find.byKey(const Key('set-vault-pin-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create Master Vault PIN'), findsOneWidget);

    // Enter 1 2 3 4
    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    // Verify Active status and Reset button
    expect(find.text('PIN Security Active'), findsOneWidget);
    expect(find.byKey(const Key('reset-vault-pin-button')), findsOneWidget);

    // Reset Vault
    await tester.tap(find.byKey(const Key('reset-vault-pin-button')));
    await tester.pumpAndSettle();

    expect(find.text('Reset Secure Vault?'), findsOneWidget);
    await tester.tap(find.text('Reset Vault'));
    await tester.pumpAndSettle();

    // Verify reset to default unlocked state
    expect(find.text('Vault Unlocked'), findsOneWidget);
  });

  testWidgets('NotificationsScreen lists schedule channels, toggles, and triggers test alert',
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
          home: NotificationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('🔔 Notifications & Alerts'), findsOneWidget);
    expect(find.text('🌅 Morning Kickstart'), findsOneWidget);
    expect(find.text('📋 Task Deadlines & Action Queue'), findsOneWidget);
    expect(find.text('🔥 Habit Streaks Alert'), findsOneWidget);
    expect(find.text('📖 Daily Reflection & Review'), findsOneWidget);

    // Trigger test alert
    final testButtons = find.text('Test Alert');
    expect(testButtons, findsWidgets);
    await tester.tap(testButtons.first);
    await tester.pumpAndSettle();
  });
}
