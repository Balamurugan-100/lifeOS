import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifeos_notes/lifeos_notes.dart';

import '../app.dart';
import '../home/home_controller.dart';
import '../theme/theme_controller.dart';
import 'notes_screen.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.note});
  final Note? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _folder;
  late List<String> _tags;
  late bool _isPinned;
  bool _previewMode = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _folder = widget.note?.folder ?? 'General';
    _tags = List.from(widget.note?.tags ?? []);
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled Note'
        : _titleController.text.trim();
    final content = _contentController.text;

    final repo = await ref.read(notesRepositoryProvider.future);
    if (widget.note != null) {
      await repo.updateNote(
        widget.note!.copyWith(
          title: title,
          content: content,
          folder: _folder,
          tags: _tags,
          isPinned: _isPinned,
        ),
      );
    } else {
      final id = 'note_${DateTime.now().millisecondsSinceEpoch}';
      await repo.addNote(
        id: id,
        title: title,
        content: content,
        folder: _folder,
        tags: _tags,
        isPinned: _isPinned,
      );
    }

    ref.invalidate(notesListProvider);
    ref.invalidate(summariesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved!'),
          backgroundColor: NeonPalette.mint,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid) {
      _contentController.text = '$text$prefix$suffix';
      return;
    }
    final selectedText = selection.textInside(text);
    final replacement = '$prefix$selectedText$suffix';
    _contentController.text = selection.textBefore(text) +
        replacement +
        selection.textAfter(text);
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + prefix.length + selectedText.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            tooltip: _isPinned ? 'Unpin Note' : 'Pin Note',
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _isPinned ? NeonPalette.amber : null,
            ),
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            tooltip: _previewMode ? 'Edit Mode' : 'Markdown Preview',
            icon: Icon(_previewMode ? Icons.edit_note : Icons.visibility_outlined),
            onPressed: () => setState(() => _previewMode = !_previewMode),
          ),
          IconButton(
            key: const Key('saveNoteButton'),
            tooltip: 'Save',
            icon: const Icon(Icons.check, color: NeonPalette.cyan),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Note Title...',
                border: InputBorder.none,
              ),
            ),
          ),
          if (!_previewMode) _buildFormattingBar(),
          const Divider(height: 1),
          Expanded(
            child: _previewMode
                ? Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    child: Markdown(
                      data: _contentController.text.isEmpty
                          ? '_No content entered yet._'
                          : _contentController.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        code: const TextStyle(
                          backgroundColor: NeonPalette.surfaceDark,
                          fontFamily: 'monospace',
                          color: NeonPalette.mint,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: NeonPalette.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeonPalette.borderDark),
                        ),
                        blockquoteDecoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: NeonPalette.cyan,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                      decoration: const InputDecoration(
                        hintText: 'Start typing markdown...\n\n# Headings\n- [ ] Task lists\n**Bold**, *Italics*\n```code blocks```',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _formatButton('H1', () => _insertMarkdown('# ')),
          _formatButton('H2', () => _insertMarkdown('## ')),
          _formatButton('H3', () => _insertMarkdown('### ')),
          const SizedBox(width: 6),
          _formatButton('B', () => _insertMarkdown('**', '**'), isBold: true),
          _formatButton('I', () => _insertMarkdown('*', '*'), isItalic: true),
          _formatButton('Code', () => _insertMarkdown('`', '`')),
          _formatButton('Block', () => _insertMarkdown('\n```dart\n', '\n```\n')),
          _formatButton('List', () => _insertMarkdown('- ')),
          _formatButton('[ ] Todo', () => _insertMarkdown('- [ ] ')),
          _formatButton('Quote', () => _insertMarkdown('> ')),
        ],
      ),
    );
  }

  Widget _formatButton(String label, VoidCallback onTap,
      {bool isBold = false, bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ActionChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
