import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(ProviderScope(
    overrides: [
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
    child: const LifeOSApp(),
  ));
}
