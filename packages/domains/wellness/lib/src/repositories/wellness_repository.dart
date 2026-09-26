import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

import '../database/wellness_database.dart';
import '../models/wellness_log.dart';

class WellnessRepository {
  WellnessRepository(this._db);

  final WellnessDatabase _db;

  WellnessLog _mapToDomain(WellnessLogData r) {
    List<String> factorList = [];
    try {
      final list = jsonDecode(r.factors) as List;
      factorList = list.map((e) => e.toString()).toList();
    } catch (_) {}

    return WellnessLog(
      id: r.id,
      date: r.date,
      bedtime: r.bedtime,
      wakeTime: r.wakeTime,
      sleepDurationMinutes: r.sleepDurationMinutes,
      sleepQualityScore: r.sleepQualityScore,
      energyScore: r.energyScore,
      stepCount: r.stepCount,
      waterMl: r.waterMl,
      factors: factorList,
      notes: r.notes,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  Future<WellnessLog> logWellness({
    required String date,
    String? bedtime,
    String? wakeTime,
    int sleepDurationMinutes = 420,
    int sleepQualityScore = 4,
    int energyScore = 4,
    int stepCount = 0,
    int waterMl = 2000,
    List<String> factors = const [],
    String? notes,
  }) async {
    final now = utcNow();
    final existing = await (_db.select(_db.wellnessLogs)..where((tbl) => tbl.date.equals(date))).getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.wellnessLogs)..where((tbl) => tbl.id.equals(existing.id))).write(
        WellnessLogsCompanion(
          bedtime: Value(bedtime),
          wakeTime: Value(wakeTime),
          sleepDurationMinutes: Value(sleepDurationMinutes),
          sleepQualityScore: Value(sleepQualityScore),
          energyScore: Value(energyScore),
          stepCount: Value(stepCount),
          waterMl: Value(waterMl),
          factors: Value(jsonEncode(factors)),
          notes: Value(notes),
          updatedAt: Value(now),
        ),
      );
      return WellnessLog(
        id: existing.id,
        date: date,
        bedtime: bedtime,
        wakeTime: wakeTime,
        sleepDurationMinutes: sleepDurationMinutes,
        sleepQualityScore: sleepQualityScore,
        energyScore: energyScore,
        stepCount: stepCount,
        waterMl: waterMl,
        factors: factors,
        notes: notes,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
    } else {
      final id = newId();
      await _db.into(_db.wellnessLogs).insert(
            WellnessLogsCompanion.insert(
              id: id,
              date: date,
              bedtime: Value(bedtime),
              wakeTime: Value(wakeTime),
              sleepDurationMinutes: Value(sleepDurationMinutes),
              sleepQualityScore: Value(sleepQualityScore),
              energyScore: Value(energyScore),
              stepCount: Value(stepCount),
              waterMl: Value(waterMl),
              factors: Value(jsonEncode(factors)),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );

      return WellnessLog(
        id: id,
        date: date,
        bedtime: bedtime,
        wakeTime: wakeTime,
        sleepDurationMinutes: sleepDurationMinutes,
        sleepQualityScore: sleepQualityScore,
        energyScore: energyScore,
        stepCount: stepCount,
        waterMl: waterMl,
        factors: factors,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );
    }
  }

  Future<WellnessLog?> getLogForDate(String date) async {
    final row = await (_db.select(_db.wellnessLogs)..where((tbl) => tbl.date.equals(date))).getSingleOrNull();
    return row == null ? null : _mapToDomain(row);
  }

  Future<List<WellnessLog>> getAllLogs({int limit = 30}) async {
    final rows = await (_db.select(_db.wellnessLogs)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)])
          ..limit(limit))
        .get();
    return rows.map(_mapToDomain).toList();
  }

  Future<({double avgSleepDurationHours, double avgEnergyScore, double avgQualityScore})> getAverages({int days = 7}) async {
    final logs = await getAllLogs(limit: days);
    if (logs.isEmpty) {
      return (avgSleepDurationHours: 0.0, avgEnergyScore: 0.0, avgQualityScore: 0.0);
    }

    final totalMinutes = logs.fold<int>(0, (sum, l) => sum + l.sleepDurationMinutes);
    final totalEnergy = logs.fold<int>(0, (sum, l) => sum + l.energyScore);
    final totalQuality = logs.fold<int>(0, (sum, l) => sum + l.sleepQualityScore);

    return (
      avgSleepDurationHours: (totalMinutes / logs.length) / 60.0,
      avgEnergyScore: totalEnergy / logs.length,
      avgQualityScore: totalQuality / logs.length,
    );
  }
}
