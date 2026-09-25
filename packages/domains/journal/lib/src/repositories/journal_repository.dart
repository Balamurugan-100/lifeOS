import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/journal_database.dart';
import '../models/journal_entry.dart';

class JournalRepository {
  JournalRepository(this._db);

  final JournalDatabase _db;

  JournalEntry _mapToDomain(JournalEntryData row) {
    List<String> tagsList = [];
    try {
      final decoded = jsonDecode(row.tags);
      if (decoded is List) {
        tagsList = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return JournalEntry(
      id: row.id,
      date: row.entryDate,
      moodScore: row.moodScore,
      gratitude: row.gratitude,
      reflection: row.reflection,
      tags: tagsList,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<JournalEntry> recordEntry({
    required String id,
    required String date,
    required int moodScore,
    String? gratitude,
    required String reflection,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final existing = await (_db.select(_db.journalEntries)
          ..where((t) => t.entryDate.equals(date)))
        .getSingleOrNull();

    if (existing != null) {
      final updated = existing.copyWith(
        moodScore: moodScore,
        gratitude: Value(gratitude),
        reflection: reflection,
        tags: jsonEncode(tags),
        updatedAt: now,
      );
      await _db.update(_db.journalEntries).replace(updated);
      return _mapToDomain(updated);
    } else {
      final newRow = JournalEntriesCompanion.insert(
        id: id,
        entryDate: date,
        moodScore: Value(moodScore),
        gratitude: Value(gratitude),
        reflection: Value(reflection),
        tags: Value(jsonEncode(tags)),
        createdAt: now,
        updatedAt: now,
      );
      await _db.into(_db.journalEntries).insert(newRow);
      return JournalEntry(
        id: id,
        date: date,
        moodScore: moodScore,
        gratitude: gratitude,
        reflection: reflection,
        tags: tags,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  Future<JournalEntry?> getEntryByDate(String date) async {
    final row = await (_db.select(_db.journalEntries)
          ..where((t) => t.entryDate.equals(date)))
        .getSingleOrNull();
    return row == null ? null : _mapToDomain(row);
  }

  Future<JournalEntry?> getEntryById(String id) async {
    final row = await (_db.select(_db.journalEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapToDomain(row);
  }

  Future<List<JournalEntry>> getAllEntries() async {
    final rows = await (_db.select(_db.journalEntries)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.entryDate,
                  mode: OrderingMode.desc,
                )
          ]))
        .get();
    return rows.map(_mapToDomain).toList();
  }

  Future<bool> deleteEntry(String id) async {
    final count = await (_db.delete(_db.journalEntries)
          ..where((t) => t.id.equals(id)))
        .go();
    return count > 0;
  }

  Future<Map<String, int>> getMoodHistory({int limit = 30}) async {
    final entries = await getAllEntries();
    final map = <String, int>{};
    for (final e in entries.take(limit)) {
      map[e.date] = e.moodScore;
    }
    return map;
  }

  Future<double> getAverageMoodScore({int limit = 7}) async {
    final entries = await getAllEntries();
    if (entries.isEmpty) return 0.0;
    final recent = entries.take(limit).toList();
    final total = recent.fold<int>(0, (sum, e) => sum + e.moodScore);
    return total / recent.length;
  }
}
