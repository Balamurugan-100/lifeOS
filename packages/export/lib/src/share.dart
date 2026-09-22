import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Delivers an export file through the device share sheet in a single action
/// (FR-013, export contract rule 3).
///
/// `share_plus` opens the platform share sheet; the user picks where the
/// portable JSON envelope goes (files app, messaging, cloud, ...).
Future<void> shareExportFile(File file) async {
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/json')],
    subject: 'LifeOS export',
    text: 'LifeOS data export (portable JSON)',
  );
}