import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_rituals/lifeos_rituals.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';

final ritualsDataProvider = FutureProvider.autoDispose<List<Ritual>>((ref) async {
  final repo = await ref.watch(ritualsRepositoryProvider.future);
  return repo.getRituals();
});

class RitualsScreen extends ConsumerStatefulWidget {
  const RitualsScreen({super.key});

  @override
  ConsumerState<RitualsScreen> createState() => _RitualsScreenState();
}

class _RitualsScreenState extends ConsumerState<RitualsScreen> {
  Future<void> _toggleStep(String ritualId, String stepId) async {
    final repo = await ref.read(ritualsRepositoryProvider.future);
    await repo.toggleStepCompletion(ritualId, stepId);
    ref.invalidate(ritualsDataProvider);
    ref.invalidate(summariesProvider);
  }

  Future<void> _deleteRitual(String ritualId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ritual?'),
        content: Text('Are you sure you want to remove "$name"? All step logs will be cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NeonPalette.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = await ref.read(ritualsRepositoryProvider.future);
      await repo.deleteRitual(ritualId);
      ref.invalidate(ritualsDataProvider);
      ref.invalidate(summariesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Removed "$name"'),
            backgroundColor: NeonPalette.rose,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showAddRitualDialog() {
    final nameCtrl = TextEditingController();
    final step1Ctrl = TextEditingController(text: 'Hydrate & Stretch');
    final step2Ctrl = TextEditingController(text: '5m Mindfulness');
    RitualType selectedType = RitualType.morning;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Custom Ritual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('ritual-name-input'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ritual Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SegmentedButton<RitualType>(
                  segments: const [
                    ButtonSegment(value: RitualType.morning, label: Text('Morning 🌅')),
                    ButtonSegment(value: RitualType.evening, label: Text('Evening 🌙')),
                    ButtonSegment(value: RitualType.custom, label: Text('Custom ⚡')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (set) => setSheetState(() => selectedType = set.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: step1Ctrl,
                  decoration: const InputDecoration(labelText: 'Step 1', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: step2Ctrl,
                  decoration: const InputDecoration(labelText: 'Step 2', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('save-ritual-button'),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isNotEmpty) {
                        final repo = await ref.read(ritualsRepositoryProvider.future);
                        final steps = <(String, int)>[];
                        if (step1Ctrl.text.isNotEmpty) steps.add((step1Ctrl.text.trim(), 5));
                        if (step2Ctrl.text.isNotEmpty) steps.add((step2Ctrl.text.trim(), 5));

                        await repo.createRitual(
                          name: name,
                          type: selectedType,
                          steps: steps,
                        );
                        ref.invalidate(ritualsDataProvider);
                        ref.invalidate(summariesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Save Ritual'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ritualsAsync = ref.watch(ritualsDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌅 Rituals & Routines', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            key: const Key('add-ritual-button'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Custom Ritual',
            onPressed: _showAddRitualDialog,
          ),
        ],
      ),
      body: ritualsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: NeonPalette.cyan)),
        error: (err, _) => Center(child: Text('Error loading rituals: $err')),
        data: (rituals) {
          if (rituals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: NeonPalette.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wb_sunny_outlined, size: 48, color: NeonPalette.amber),
                    ),
                    const SizedBox(height: 16),
                    const Text('No rituals configured yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Design your personalized morning and evening routines without any mandatory defaults.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('create-first-ritual-button'),
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _showAddRitualDialog,
                      label: const Text('Create New Ritual'),
                      style: FilledButton.styleFrom(backgroundColor: NeonPalette.amber, foregroundColor: Colors.black),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rituals.length,
            itemBuilder: (context, index) {
              final ritual = rituals[index];
              return _buildRitualCard(ritual, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildRitualCard(Ritual ritual, bool isDark) {
    final isMorning = ritual.type == RitualType.morning;
    final accentColor = isMorning ? NeonPalette.amber : NeonPalette.violet;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDark ? NeonPalette.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ritual.isCompletedToday
              ? NeonPalette.mint.withValues(alpha: 0.5)
              : (isDark ? NeonPalette.borderDark : Colors.grey.shade200),
          width: 1.5,
        ),
        boxShadow: [
          if (ritual.isCompletedToday)
            BoxShadow(
              color: NeonPalette.mint.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isMorning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ritual.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${ritual.totalMinutes} mins • 🔥 ${ritual.streak} day streak',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ritual.isCompletedToday)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: NeonPalette.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: NeonPalette.mint),
                        SizedBox(width: 4),
                        Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: NeonPalette.mint)),
                      ],
                    ),
                  ),
                IconButton(
                  key: Key('delete-ritual-${ritual.id}'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                  tooltip: 'Delete Ritual',
                  onPressed: () => _deleteRitual(ritual.id, ritual.name),
                ),
              ],
            ),
          ),
          // Step Progress Bar
          ClipRRect(
            child: LinearProgressIndicator(
              value: ritual.completionProgress,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                ritual.isCompletedToday ? NeonPalette.mint : accentColor,
              ),
              minHeight: 4,
            ),
          ),
          // Steps checklist
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: ritual.steps.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.grey.shade100,
            ),
            itemBuilder: (context, sIndex) {
              final step = ritual.steps[sIndex];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: InkWell(
                  onTap: () => _toggleStep(ritual.id, step.id),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.isCompleted
                          ? NeonPalette.mint
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Icon(
                      step.isCompleted ? Icons.check : Icons.circle_outlined,
                      size: 16,
                      color: step.isCompleted ? Colors.black : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
                title: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                    color: step.isCompleted
                        ? (isDark ? Colors.white38 : Colors.black38)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                trailing: Text(
                  '${step.durationMinutes}m',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
