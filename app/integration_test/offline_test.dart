import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// US4 offline operation (T056): every core flow (home, Tasks, Habits) works
/// with no network available. LifeOS makes no network calls at all — the
/// flows below run headless exactly as they would in airplane mode, and a
/// static audit asserts no connectivity APIs are referenced (FR-008).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all core flows work offline (SC-004)', (tester) async {
    await pumpLifeOSApp(tester);

    // Home.
    expect(find.byKey(const Key('emptystate')), findsOneWidget);

    // Tasks.
    await tester.tap(find.byKey(const Key('openTasks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTaskFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('taskTitleField')), 'Offline');
    await tester.tap(find.byKey(const Key('saveTask')));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Habits.
    await tester.tap(find.byKey(const Key('openHabits')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No habits yet'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  test('no network packages are referenced (FR-008)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final forbidden in ['http:', 'dio:', 'grpc:', 'web_socket', 'socket_io']) {
      expect(pubspec.contains(forbidden), isFalse,
          reason: 'app must not depend on $forbidden (local-first, no sync)');
    }
  });

  test('Android manifest does not request INTERNET permission (FR-008)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android.permission.INTERNET'), isFalse,
        reason: 'no INTERNET permission: the app must not be able to dial out');
  });
}