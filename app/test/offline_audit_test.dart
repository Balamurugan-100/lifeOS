import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// US4 static audit (FR-008): LifeOS is local-first and must not be able to
/// dial out at all.
///
/// This lives in the host-side `flutter test` suite rather than
/// `integration_test/` because it reads the repo's own files — those are not
/// present on the device the integration tests run on, where `File('pubspec.yaml')`
/// would resolve against the device filesystem. The behavioural half of FR-008
/// (every core flow works with no network) is in
/// `integration_test/offline_test.dart`.
void main() {
  test('no network packages are referenced', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final forbidden in [
      'http:',
      'dio:',
      'grpc:',
      'web_socket',
      'socket_io',
    ]) {
      expect(pubspec.contains(forbidden), isFalse,
          reason: 'app must not depend on $forbidden (local-first, no sync)');
    }
  });

  test('the release manifest does not request INTERNET permission', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('android.permission.INTERNET'), isFalse,
        reason: 'no INTERNET permission: the app must not be able to dial out');
  });

  test('no source file imports a networking API', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final needle in [
        "package:http/",
        "package:dio/",
        "package:web_socket",
        'dart:io\');',
      ]) {
        // `dart:io` is allowed for local files, never for sockets.
        if (needle == 'dart:io\');') {
          if (RegExp(r'Socket|HttpClient|HttpServer').hasMatch(source)) {
            offenders.add('${entity.path} (uses a dart:io network API)');
          }
          continue;
        }
        if (source.contains(needle)) {
          offenders.add('${entity.path} ($needle)');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'no app source may talk to a network (FR-008)');
  });
}
