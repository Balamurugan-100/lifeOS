import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_export/lifeos_export.dart';
import 'package:path_provider/path_provider.dart';

import '../app.dart';

/// One-tap portable export (FR-013): builds the JSON envelope from every
/// enabled domain and offers it through the device share sheet. Failure
/// never touches data and the action can be retried (export contract rule 5).
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  Future<void> _exportNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final tasks = await ref.read(taskRepositoryProvider.future);
      final habits = await ref.read(habitRepositoryProvider.future);
      final exporter = LifeOSExporter(tasks: tasks, habits: habits);

      final temp = await getTemporaryDirectory();
      final target = File('${temp.path}/lifeos-export.json');
      await exporter.writeTo(target);

      messenger.showSnackBar(
        SnackBar(content: Text('Export written to ${target.path}')),
      );
      await shareExportFile(target);
    } on ExportException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed — please retry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.ios_share,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your data, yours to move',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Creates one portable JSON file with every task, habit and '
                'entry on this device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('exportNow'),
                onPressed: () => _exportNow(context, ref),
                icon: const Icon(Icons.ios_share),
                label: const Text('Export & share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}