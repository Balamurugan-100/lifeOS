import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_export/lifeos_export.dart';
import 'package:path_provider/path_provider.dart';

import '../app.dart';
import '../theme/theme_controller.dart';

/// One-tap portable export (FR-013): builds the JSON envelope from every
/// enabled domain or Daily Digest (per day) and offers it through the device share sheet.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _dailyAsMarkdown = true;

  Future<LifeOSExporter> _buildExporter() async {
    final tasks = await ref.read(taskRepositoryProvider.future);
    final habits = await ref.read(habitRepositoryProvider.future);
    final finance = await ref.read(financeRepositoryProvider.future);
    final time = await ref.read(timeRepositoryProvider.future);

    return LifeOSExporter(
      tasks: tasks,
      habits: habits,
      finance: finance,
      time: time,
    );
  }

  Future<void> _exportFullBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final exporter = await _buildExporter();
      final temp = await getTemporaryDirectory();
      final target = File('${temp.path}/lifeos-full-export.json');
      await exporter.writeTo(target);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Full backup written to ${target.path}'),
          backgroundColor: LifeOSPalette.teal,
        ),
      );
      await shareExportFile(target);
    } on ExportException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed — please retry: $error'),
          backgroundColor: LifeOSPalette.rust,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: LifeOSPalette.rust,
        ),
      );
    }
  }

  Future<void> _exportDailyDigest(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final exporter = await _buildExporter();
      final temp = await getTemporaryDirectory();
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final ext = _dailyAsMarkdown ? 'md' : 'json';
      final target = File('${temp.path}/lifeos-daily-$dateStr.$ext');

      await exporter.writeDailyExportTo(
        _selectedDate,
        target,
        asMarkdown: _dailyAsMarkdown,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Daily digest ($ext) saved to ${target.path}'),
          backgroundColor: LifeOSPalette.sage,
        ),
      );
      await shareExportFile(target);
    } on ExportException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Daily export failed: $error'),
          backgroundColor: LifeOSPalette.rust,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: LifeOSPalette.rust,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export & Data Privacy',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: Daily Digest Export
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? LifeOSPalette.borderDark : Colors.grey.shade300,
              ),
            ),
            color: isDark ? LifeOSPalette.surfaceCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: LifeOSPalette.sage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.today,
                            color: LifeOSPalette.sage, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Digest Export',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Export single-day logs & summaries',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Generates a comprehensive summary of mood, habits completed, accomplished tasks, focus minutes, transactions, and notes for the selected date.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(
                            'Date: $dateStr',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Format:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Markdown (.md)'),
                        selected: _dailyAsMarkdown,
                        selectedColor: LifeOSPalette.sage.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: _dailyAsMarkdown
                              ? LifeOSPalette.sage
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _dailyAsMarkdown
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _dailyAsMarkdown = true);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('JSON (.json)'),
                        selected: !_dailyAsMarkdown,
                        selectedColor: LifeOSPalette.teal.withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: !_dailyAsMarkdown
                              ? LifeOSPalette.teal
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: !_dailyAsMarkdown
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _dailyAsMarkdown = false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('exportDailyButton'),
                      onPressed: () => _exportDailyDigest(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: LifeOSPalette.sage,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.share, size: 20),
                      label: Text(
                        'Export $dateStr Digest (${_dailyAsMarkdown ? 'Markdown' : 'JSON'})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Full System Backup (FR-013)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? LifeOSPalette.borderDark : Colors.grey.shade300,
              ),
            ),
            color: isDark ? LifeOSPalette.surfaceCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: LifeOSPalette.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_download,
                            color: LifeOSPalette.teal, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full LifeOS Backup',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Portable JSON archive of all 7 domains',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Creates one single portable JSON file containing every task, habit, transaction, journal entry, focus session, OKR goal, and markdown note on this device.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('exportNow'),
                      onPressed: () => _exportFullBackup(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: LifeOSPalette.teal,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.ios_share, size: 20),
                      label: const Text(
                        'Export & Share Full Backup',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}