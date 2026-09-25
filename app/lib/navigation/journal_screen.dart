import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_core/lifeos_core.dart' show isoDate, todayLocal;
import 'package:lifeos_journal/lifeos_journal.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';

final journalEntriesProvider =
    FutureProvider.autoDispose<List<JournalEntry>>((ref) async {
  final repo = await ref.watch(journalRepositoryProvider.future);
  return repo.getAllEntries();
});

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  int _selectedMood = 4;
  final TextEditingController _gratitudeController = TextEditingController();
  final TextEditingController _reflectionController = TextEditingController();
  final List<String> _selectedTags = [];
  String _searchQuery = '';
  final List<String> _availableTags = [
    'Work',
    'Health',
    'Family',
    'Personal',
    'Growth',
    'Travel'
  ];

  @override
  void initState() {
    super.initState();
    _loadTodayEntry();
  }

  Future<void> _loadTodayEntry() async {
    final repo = await ref.read(journalRepositoryProvider.future);
    final today = isoDate(todayLocal());
    final entry = await repo.getEntryByDate(today);
    if (entry != null && mounted) {
      setState(() {
        _selectedMood = entry.moodScore;
        _gratitudeController.text = entry.gratitude ?? '';
        _reflectionController.text = entry.reflection;
        _selectedTags.clear();
        _selectedTags.addAll(entry.tags);
      });
    }
  }

  @override
  void dispose() {
    _gratitudeController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _saveTodayEntry() async {
    final repo = await ref.read(journalRepositoryProvider.future);
    final today = isoDate(todayLocal());
    final id = 'journal_$today';

    await repo.recordEntry(
      id: id,
      date: today,
      moodScore: _selectedMood,
      gratitude: _gratitudeController.text.trim().isEmpty
          ? null
          : _gratitudeController.text.trim(),
      reflection: _reflectionController.text.trim(),
      tags: _selectedTags,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Daily reflection saved!'),
          backgroundColor: NeonPalette.mint,
        ),
      );
      ref.invalidate(journalEntriesProvider);
      ref.invalidate(summariesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(journalEntriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal & Mood'),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (entries) {
          final filteredEntries = entries.where((e) {
            if (_searchQuery.isEmpty) return true;
            return e.reflection.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (e.gratitude?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                e.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
          }).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildTodayCheckinCard(theme),
              const SizedBox(height: 20),
              _buildPastEntriesHeader(theme),
              const SizedBox(height: 10),
              if (filteredEntries.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No journal entries found.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...filteredEntries.map((e) => _buildEntryTile(theme, e)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayCheckinCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: NeonPalette.borderBright, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: NeonPalette.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.wb_sunny_rounded,
                      color: NeonPalette.amber, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  "Today's Check-in",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  isoDate(todayLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'How are you feeling today?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final mood in MoodType.values)
                  InkWell(
                    key: Key('mood_${mood.score}'),
                    onTap: () => setState(() => _selectedMood = mood.score),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedMood == mood.score
                            ? NeonPalette.cyan.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedMood == mood.score
                              ? NeonPalette.cyan
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(mood.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            mood.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _selectedMood == mood.score
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _selectedMood == mood.score
                                  ? NeonPalette.cyan
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gratitudeController,
              decoration: InputDecoration(
                labelText: 'Gratitude (What are you thankful for?)',
                hintText: 'e.g. Clear morning weather, finished sprint on time...',
                prefixIcon: const Icon(Icons.favorite_outline, size: 20),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reflectionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Daily Reflection & Thoughts',
                hintText: 'Wins, learnings, observations...',
                prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final tag in _availableTags)
                  FilterChip(
                    label: Text(tag),
                    selected: _selectedTags.contains(tag),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: NeonPalette.violet.withValues(alpha: 0.25),
                    checkmarkColor: NeonPalette.violet,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _selectedTags.contains(tag)
                          ? NeonPalette.violet
                          : theme.colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('saveJournalButton'),
                onPressed: _saveTodayEntry,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Reflection'),
                style: FilledButton.styleFrom(
                  backgroundColor: NeonPalette.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastEntriesHeader(ThemeData theme) {
    return Row(
      children: [
        Text(
          'Past Entries',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 160,
          height: 36,
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(ThemeData theme, JournalEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: NeonPalette.borderDark, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.mood.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  entry.mood.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  entry.date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (entry.gratitude != null && entry.gratitude!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '🙏 ${entry.gratitude}',
                style: TextStyle(
                  fontSize: 13,
                  color: NeonPalette.amber.withValues(alpha: 0.9),
                ),
              ),
            ],
            if (entry.reflection.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.reflection,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final tag in entry.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: NeonPalette.violet.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 11,
                          color: NeonPalette.violet,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
