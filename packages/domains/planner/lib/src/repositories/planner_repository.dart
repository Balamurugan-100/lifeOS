import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

import '../database/planner_database.dart';
import '../models/time_block.dart';

class PlannerRepository {
  PlannerRepository(this._db);

  final PlannerDatabase _db;

  TimeBlock _mapToDomain(TimeBlockData r) {
    return TimeBlock(
      id: r.id,
      title: r.title,
      date: r.date,
      startMinute: r.startMinute,
      durationMinutes: r.durationMinutes,
      category: BlockCategory.fromString(r.category),
      linkedTaskId: r.linkedTaskId,
      colorHex: r.colorHex,
      isCompleted: r.isCompleted,
      notes: r.notes,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  Future<TimeBlock> createBlock({
    required String title,
    required String date,
    required int startMinute,
    required int durationMinutes,
    BlockCategory category = BlockCategory.focus,
    String? linkedTaskId,
    String colorHex = '#38BDF8',
    String? notes,
  }) async {
    final id = newId();
    final now = utcNow();

    await _db.into(_db.timeBlocks).insert(
          TimeBlocksCompanion.insert(
            id: id,
            title: title,
            date: date,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            category: Value(category.name),
            linkedTaskId: Value(linkedTaskId),
            colorHex: Value(colorHex),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return TimeBlock(
      id: id,
      title: title,
      date: date,
      startMinute: startMinute,
      durationMinutes: durationMinutes,
      category: category,
      linkedTaskId: linkedTaskId,
      colorHex: colorHex,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<TimeBlock>> getBlocksForDate(String date) async {
    final rows = await (_db.select(_db.timeBlocks)
          ..where((tbl) => tbl.date.equals(date))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.startMinute)]))
        .get();

    return rows.map(_mapToDomain).toList();
  }

  Future<List<TimeBlock>> getAllBlocks() async {
    final rows = await (_db.select(_db.timeBlocks)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .get();
    return rows.map(_mapToDomain).toList();
  }

  Future<void> updateBlock(TimeBlock block) async {
    final now = utcNow();
    await (_db.update(_db.timeBlocks)..where((tbl) => tbl.id.equals(block.id))).write(
      TimeBlocksCompanion(
        title: Value(block.title),
        date: Value(block.date),
        startMinute: Value(block.startMinute),
        durationMinutes: Value(block.durationMinutes),
        category: Value(block.category.name),
        linkedTaskId: Value(block.linkedTaskId),
        colorHex: Value(block.colorHex),
        isCompleted: Value(block.isCompleted),
        notes: Value(block.notes),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> toggleBlockCompletion(String id) async {
    final block = await (_db.select(_db.timeBlocks)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (block == null) return;

    final now = utcNow();
    await (_db.update(_db.timeBlocks)..where((tbl) => tbl.id.equals(id))).write(
      TimeBlocksCompanion(
        isCompleted: Value(!block.isCompleted),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteBlock(String id) async {
    await (_db.delete(_db.timeBlocks)..where((tbl) => tbl.id.equals(id))).go();
  }
}
