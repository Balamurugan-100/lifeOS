import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

import '../database/rituals_database.dart';
import '../models/ritual.dart';

class RitualsRepository {
  RitualsRepository(this._db);

  final RitualsDatabase _db;

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> seedDefaultsIfEmpty() async {
    final count = await (_db.select(_db.ritualEntries)).get();
    if (count.isNotEmpty) return;

    final now = utcNow();

    // 1. Morning Routine
    final morningId = newId();
    await _db.into(_db.ritualEntries).insert(
          RitualEntriesCompanion.insert(
            id: morningId,
            name: 'Morning Kickstart Ritual',
            type: 'morning',
            description: const Value('Awaken body, ground mind, and establish focus.'),
            iconName: const Value('wb_sunny_rounded'),
            colorHex: const Value('#F59E0B'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final morningSteps = [
      ('Hydrate (500ml) & Quick Stretch', 5),
      ('5m Morning Reflection & Gratitude', 5),
      ('Review Top 3 High-Priority Tasks', 5),
    ];

    for (var i = 0; i < morningSteps.length; i++) {
      await _db.into(_db.ritualStepEntries).insert(
            RitualStepEntriesCompanion.insert(
              id: newId(),
              ritualId: morningId,
              title: morningSteps[i].$1,
              durationMinutes: Value(morningSteps[i].$2),
              orderIndex: Value(i),
              createdAt: now,
            ),
          );
    }

    // 2. Evening Routine
    final eveningId = newId();
    await _db.into(_db.ritualEntries).insert(
          RitualEntriesCompanion.insert(
            id: eveningId,
            name: 'Evening Shutdown & Wind-down',
            type: 'evening',
            description: const Value('Close open loops, log daily wins, and prep for rest.'),
            iconName: const Value('nightlight_round'),
            colorHex: const Value('#8B5CF6'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final eveningSteps = [
      ('Log Daily Reflection & Mood Score', 5),
      ('Clear Inbox & Review Accomplishments', 5),
      ('Set Tomorrow Blueprint & Screens Off', 10),
    ];

    for (var i = 0; i < eveningSteps.length; i++) {
      await _db.into(_db.ritualStepEntries).insert(
            RitualStepEntriesCompanion.insert(
              id: newId(),
              ritualId: eveningId,
              title: eveningSteps[i].$1,
              durationMinutes: Value(eveningSteps[i].$2),
              orderIndex: Value(i),
              createdAt: now,
            ),
          );
    }
  }

  Future<List<Ritual>> getRituals() async {
    await seedDefaultsIfEmpty();

    final today = _today();
    final ritualRows = await (_db.select(_db.ritualEntries)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();

    final results = <Ritual>[];

    for (final row in ritualRows) {
      final stepRows = await (_db.select(_db.ritualStepEntries)
            ..where((tbl) => tbl.ritualId.equals(row.id))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.orderIndex)]))
          .get();

      // Check today's execution log
      final execLog = await (_db.select(_db.ritualExecutionLogs)
            ..where((tbl) => tbl.ritualId.equals(row.id) & tbl.date.equals(today)))
          .getSingleOrNull();

      final completedIds = <String>{};
      if (execLog != null) {
        try {
          final list = jsonDecode(execLog.completedStepIds) as List;
          completedIds.addAll(list.map((e) => e.toString()));
        } catch (_) {}
      }

      final steps = stepRows.map((s) {
        return RitualStep(
          id: s.id,
          ritualId: s.ritualId,
          title: s.title,
          description: s.description,
          durationMinutes: s.durationMinutes,
          orderIndex: s.orderIndex,
          isCompleted: completedIds.contains(s.id),
        );
      }).toList();

      results.add(
        Ritual(
          id: row.id,
          name: row.name,
          type: RitualType.fromString(row.type),
          description: row.description,
          iconName: row.iconName,
          colorHex: row.colorHex,
          steps: steps,
          isActive: row.isActive,
          streak: row.streak,
          lastCompletedDate: row.lastCompletedDate,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
      );
    }

    return results;
  }

  Future<Ritual> createRitual({
    required String name,
    required RitualType type,
    String? description,
    String iconName = 'routine',
    String colorHex = '#38BDF8',
    List<(String title, int durationMins)> steps = const [],
  }) async {
    final id = newId();
    final now = utcNow();

    await _db.into(_db.ritualEntries).insert(
          RitualEntriesCompanion.insert(
            id: id,
            name: name,
            type: type.name,
            description: Value(description),
            iconName: Value(iconName),
            colorHex: Value(colorHex),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final stepList = <RitualStep>[];
    for (var i = 0; i < steps.length; i++) {
      final stepId = newId();
      await _db.into(_db.ritualStepEntries).insert(
            RitualStepEntriesCompanion.insert(
              id: stepId,
              ritualId: id,
              title: steps[i].$1,
              durationMinutes: Value(steps[i].$2),
              orderIndex: Value(i),
              createdAt: now,
            ),
          );
      stepList.add(
        RitualStep(
          id: stepId,
          ritualId: id,
          title: steps[i].$1,
          durationMinutes: steps[i].$2,
          orderIndex: i,
        ),
      );
    }

    return Ritual(
      id: id,
      name: name,
      type: type,
      description: description,
      iconName: iconName,
      colorHex: colorHex,
      steps: stepList,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> toggleStepCompletion(String ritualId, String stepId) async {
    final today = _today();
    final now = utcNow();

    final execLog = await (_db.select(_db.ritualExecutionLogs)
          ..where((tbl) => tbl.ritualId.equals(ritualId) & tbl.date.equals(today)))
          .getSingleOrNull();

    final completedIds = <String>{};
    if (execLog != null) {
      try {
        final list = jsonDecode(execLog.completedStepIds) as List;
        completedIds.addAll(list.map((e) => e.toString()));
      } catch (_) {}
    }

    if (completedIds.contains(stepId)) {
      completedIds.remove(stepId);
    } else {
      completedIds.add(stepId);
    }

    // Check all steps count
    final allSteps = await (_db.select(_db.ritualStepEntries)
          ..where((tbl) => tbl.ritualId.equals(ritualId)))
        .get();

    final isAllDone = allSteps.isNotEmpty && completedIds.length == allSteps.length;

    if (execLog != null) {
      await (_db.update(_db.ritualExecutionLogs)
            ..where((tbl) => tbl.id.equals(execLog.id)))
          .write(
        RitualExecutionLogsCompanion(
          completedStepIds: Value(jsonEncode(completedIds.toList())),
          isFullCompletion: Value(isAllDone),
          completedAt: Value(now),
        ),
      );
    } else {
      await _db.into(_db.ritualExecutionLogs).insert(
            RitualExecutionLogsCompanion.insert(
              id: newId(),
              ritualId: ritualId,
              date: today,
              completedStepIds: Value(jsonEncode(completedIds.toList())),
              isFullCompletion: Value(isAllDone),
              completedAt: now,
            ),
          );
    }

    // Update streak if full completion
    if (isAllDone) {
      final ritual = await (_db.select(_db.ritualEntries)
            ..where((tbl) => tbl.id.equals(ritualId)))
          .getSingleOrNull();
      if (ritual != null && ritual.lastCompletedDate != today) {
        final newStreak = (ritual.lastCompletedDate != null)
            ? ritual.streak + 1
            : 1;
        await (_db.update(_db.ritualEntries)
              ..where((tbl) => tbl.id.equals(ritualId)))
            .write(
          RitualEntriesCompanion(
            streak: Value(newStreak),
            lastCompletedDate: Value(today),
            updatedAt: Value(now),
          ),
        );
      }
    }
  }

  Future<void> deleteRitual(String id) async {
    await (_db.delete(_db.ritualStepEntries)..where((tbl) => tbl.ritualId.equals(id))).go();
    await (_db.delete(_db.ritualExecutionLogs)..where((tbl) => tbl.ritualId.equals(id))).go();
    await (_db.delete(_db.ritualEntries)..where((tbl) => tbl.id.equals(id))).go();
  }
}
