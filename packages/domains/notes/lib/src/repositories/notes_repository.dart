import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/note_database.dart';
import '../models/note.dart';

class NotesRepository {
  NotesRepository(this._db);

  final NoteDatabase _db;

  Note _mapToDomain(NoteData row) {
    List<String> tagsList = [];
    try {
      final decoded = jsonDecode(row.tags);
      if (decoded is List) {
        tagsList = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return Note(
      id: row.id,
      title: row.title,
      content: row.content,
      folder: row.folder,
      tags: tagsList,
      isPinned: row.isPinned,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<Note> addNote({
    required String id,
    required String title,
    required String content,
    String folder = 'General',
    List<String> tags = const [],
    bool isPinned = false,
  }) async {
    final now = DateTime.now();
    final newRow = NotesTableCompanion.insert(
      id: id,
      title: Value(title),
      content: Value(content),
      folder: Value(folder),
      tags: Value(jsonEncode(tags)),
      isPinned: Value(isPinned),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.notesTable).insert(newRow);
    return Note(
      id: id,
      title: title,
      content: content,
      folder: folder,
      tags: tags,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateNote(Note note) async {
    final now = DateTime.now();
    await _db.update(_db.notesTable).replace(
          NoteData(
            id: note.id,
            title: note.title,
            content: note.content,
            folder: note.folder,
            tags: jsonEncode(note.tags),
            isPinned: note.isPinned,
            isArchived: note.isArchived,
            createdAt: note.createdAt,
            updatedAt: now,
          ),
        );
  }

  Future<Note?> getNoteById(String id) async {
    final row = await (_db.select(_db.notesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapToDomain(row);
  }

  Future<List<Note>> getAllNotes({
    String? folder,
    String? tag,
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.notesTable)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.isPinned,
              mode: OrderingMode.desc,
            ),
        (t) => OrderingTerm(
              expression: t.updatedAt,
              mode: OrderingMode.desc,
            ),
      ]);

    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    if (folder != null && folder != 'All') {
      query.where((t) => t.folder.equals(folder));
    }

    final rows = await query.get();
    var notes = rows.map(_mapToDomain).toList();
    if (tag != null) {
      notes = notes.where((n) => n.tags.contains(tag)).toList();
    }
    return notes;
  }

  Future<List<Note>> searchNotes(String query) async {
    final all = await getAllNotes();
    if (query.trim().isEmpty) return all;
    final lower = query.toLowerCase();
    return all.where((n) {
      return n.title.toLowerCase().contains(lower) ||
          n.content.toLowerCase().contains(lower) ||
          n.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();
  }

  Future<void> togglePin(String id) async {
    final note = await getNoteById(id);
    if (note == null) return;
    await updateNote(note.copyWith(isPinned: !note.isPinned));
  }

  Future<bool> deleteNote(String id) async {
    final count =
        await (_db.delete(_db.notesTable)..where((t) => t.id.equals(id))).go();
    return count > 0;
  }

  Future<List<String>> getFolders() async {
    final all = await getAllNotes(includeArchived: true);
    final folders = {'General', ...all.map((n) => n.folder)};
    return folders.toList();
  }
}
