import 'package:lifeos_core/lifeos_core.dart';

import 'repositories/notes_repository.dart';

class NotesSummaryBuilder {
  NotesSummaryBuilder(this._repository);

  final NotesRepository _repository;

  Future<DomainSummary> build() async {
    final allNotes = await _repository.getAllNotes();
    final pinned = allNotes.where((n) => n.isPinned).toList();

    final counts = <String, int>{
      'notes': allNotes.length,
      'pinned': pinned.length,
    };

    final highlighted = <HighlightedItem>[];
    if (pinned.isNotEmpty) {
      for (final note in pinned.take(2)) {
        highlighted.add(
          HighlightedItem(
            id: note.id,
            title: '📌 ${note.title}',
            subtitle: note.previewSnippet,
            kind: 'notes.view',
            action: HighlightAction.openDomain,
          ),
        );
      }
    } else if (allNotes.isNotEmpty) {
      final latest = allNotes.first;
      highlighted.add(
        HighlightedItem(
          id: latest.id,
          title: '📝 ${latest.title}',
          subtitle: latest.previewSnippet,
          kind: 'notes.view',
          action: HighlightAction.openDomain,
        ),
      );
    }

    return DomainSummary(
      domainKey: 'notes',
      displayName: 'Markdown Notes',
      counts: counts,
      highlighted: highlighted,
      refreshedAt: DateTime.now().toUtc(),
    );
  }
}
