import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_notes/lifeos_notes.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';
import 'note_editor_screen.dart';

final notesListProvider =
    FutureProvider.autoDispose<List<Note>>((ref) async {
  final repo = await ref.watch(notesRepositoryProvider.future);
  return repo.getAllNotes();
});

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _selectedFolder = 'All';
  String _searchQuery = '';
  String? _selectedTag;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notes & Docs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New Folder',
            onPressed: _showCreateFolderDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NoteEditorScreen(),
            ),
          );
        },
        backgroundColor: NeonPalette.cyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.edit_note),
        label: const Text(
          'New Note',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: notesAsync.when(
        data: (allNotes) {
          final folders = {'All', ...allNotes.map((n) => n.folder)};
          final allTags = <String>{};
          for (final n in allNotes) {
            allTags.addAll(n.tags);
          }

          var filteredNotes = allNotes.where((note) {
            if (_selectedFolder != 'All' && note.folder != _selectedFolder) {
              return false;
            }
            if (_selectedTag != null && !note.tags.contains(_selectedTag)) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matchesTitle = note.title.toLowerCase().contains(query);
              final matchesContent = note.content.toLowerCase().contains(query);
              final matchesTag =
                  note.tags.any((t) => t.toLowerCase().contains(query));
              if (!matchesTitle && !matchesContent && !matchesTag) {
                return false;
              }
            }
            return true;
          }).toList();

          final pinnedNotes = filteredNotes.where((n) => n.isPinned).toList();
          final unpinnedNotes =
              filteredNotes.where((n) => !n.isPinned).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notes, markdown, tags...',
                      prefixIcon:
                          const Icon(Icons.search, color: NeonPalette.cyan),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? NeonPalette.surfaceCard
                          : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    children: folders.map((folder) {
                      final isSelected = _selectedFolder == folder;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(folder),
                          selected: isSelected,
                          selectedColor: NeonPalette.cyan.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? NeonPalette.cyan
                                : (isDark
                                    ? Colors.white70
                                    : Colors.black87),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? NeonPalette.cyan
                                : Colors.transparent,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFolder = folder);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (allTags.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (_selectedTag != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.close, size: 14),
                              label: Text('Clear: #$_selectedTag',
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: () =>
                                  setState(() => _selectedTag = null),
                            ),
                          ),
                        ...allTags.map((tag) {
                          final isSelected = _selectedTag == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text('#$tag',
                                  style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor:
                                  NeonPalette.mint.withValues(alpha: 0.25),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? NeonPalette.mint
                                    : Colors.grey,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onSelected: (sel) {
                                setState(() {
                                  _selectedTag = sel ? tag : null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              if (filteredNotes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _selectedFolder != 'All'
                              ? 'No matching notes found'
                              : 'No notes yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Write rich notes with full Markdown & folder support',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? Colors.white38 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (pinnedNotes.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin,
                              size: 16, color: NeonPalette.amber),
                          SizedBox(width: 6),
                          Text(
                            'PINNED NOTES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: NeonPalette.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildNoteCard(pinnedNotes[index], isDark),
                        childCount: pinnedNotes.length,
                      ),
                    ),
                  ),
                ],
                if (unpinnedNotes.isNotEmpty) ...[
                  if (pinnedNotes.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'ALL NOTES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildNoteCard(unpinnedNotes[index], isDark),
                        childCount: unpinnedNotes.length,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: NeonPalette.cyan),
        ),
        error: (err, stack) => Center(
          child: Text('Error loading notes: $err'),
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note, bool isDark) {
    final previewText = note.content.trim().isEmpty
        ? 'Empty note'
        : note.content.replaceAll(RegExp(r'[#*`_>~-]'), '').trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned
              ? NeonPalette.amber.withValues(alpha: 0.4)
              : (isDark ? NeonPalette.borderDark : Colors.grey.shade200),
        ),
      ),
      color: isDark ? NeonPalette.surfaceCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditorScreen(note: note),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: NeonPalette.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note.folder,
                      style: const TextStyle(
                        fontSize: 11,
                        color: NeonPalette.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (val) async {
                      if (val == 'pin') {
                        await _togglePin(note);
                      } else if (val == 'delete') {
                        await _deleteNote(note);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              note.isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin,
                              size: 16,
                              color: NeonPalette.amber,
                            ),
                            const SizedBox(width: 8),
                            Text(note.isPinned ? 'Unpin note' : 'Pin note'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: NeonPalette.rose),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: NeonPalette.rose)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                previewText,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(note.updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white30 : Colors.grey.shade500,
                    ),
                  ),
                  if (note.isPinned)
                    const Icon(Icons.push_pin,
                        size: 14, color: NeonPalette.amber),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _togglePin(Note note) async {
    final repo = await ref.read(notesRepositoryProvider.future);
    await repo.togglePin(note.id);
    ref.invalidate(notesListProvider);
    ref.invalidate(summariesProvider);
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NeonPalette.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = await ref.read(notesRepositoryProvider.future);
      await repo.deleteNote(note.id);
      ref.invalidate(notesListProvider);
      ref.invalidate(summariesProvider);
    }
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name (e.g. Work, Ideas)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _selectedFolder = text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Select / Filter'),
          ),
        ],
      ),
    );
  }
}
