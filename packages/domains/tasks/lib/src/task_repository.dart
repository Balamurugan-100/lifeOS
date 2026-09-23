import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart' show calendarDate, newId;
import 'package:lifeos_storage/lifeos_storage.dart' show utcNow;

import 'task.dart';
import 'task_database.dart' hide Task;

/// Repository over the Tasks domain table (data-model.md).
///
/// Every write refreshes `updated_at` (UTC). Manual ordering is a `position`
/// index assigned on insert (next integer), rewritten wholesale by [reorder],
/// and read back sorted by position then `created_at` so stable insertion
/// order survives position ties.
class TaskRepository {
  TaskRepository(this._db);

  final TaskDatabase _db;

  /// Adds a task with fresh UUID + UTC audit timestamps and the next free
  /// [Task.position]. [dueDate] is normalized to its calendar date; an empty
  /// (epoch) date is treated as "no due date". Returns the stored task.
  Future<Task> add(String title, {DateTime? dueDate}) async {
    final normalized = normalizeTaskTitle(title);
    final now = utcNow();
    final id = newId();
    final countExpr = _db.tasks.id.count();
    final countRow = await (_db.selectOnly(_db.tasks)..addColumns([countExpr]))
        .getSingle();
    final position = countRow.read(countExpr) ?? 0;

    await _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            id: id,
            title: normalized,
            status: TaskStatus.outstanding.name,
            dueDate: Value(_normalizeDueDate(dueDate)),
            position: position,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return Task(
      id: id,
      title: normalized,
      status: TaskStatus.outstanding,
      dueDate: _normalizeDueDate(dueDate),
      position: position,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Task?> byId(String id) async {
    final row = await (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  /// Re-trims and stores the new title, refreshing `updated_at`.
  Future<void> updateTitle(String id, String title) async {
    final normalized = normalizeTaskTitle(title);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            title: Value(normalized),
            updatedAt: Value(await _nextUpdatedAt(id)),
          ),
        );
  }

  /// Sets or clears the due date (epoch -> null), refreshing `updated_at`.
  Future<void> setDueDate(String id, DateTime? dueDate) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            dueDate: Value(_normalizeDueDate(dueDate)),
            updatedAt: Value(await _nextUpdatedAt(id)),
          ),
        );
  }

  /// Sets the status, refreshing `updated_at`. Idempotent: writing the status
  /// the row already has is a no-op (no timestamp change).
  Future<void> setStatus(String id, TaskStatus status) async {
    final current = await byId(id);
    if (current == null || current.status == status) return;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            status: Value(status.name),
            updatedAt: Value(await _nextUpdatedAt(id)),
          ),
        );
  }

  /// Flips outstanding <-> completed and returns the freshly stored task
  /// (the idempotence invariant lives in [setStatus]; flipping always writes).
  Future<Task> toggle(String id) async {
    final current = await byId(id);
    if (current == null) throw StateError('Task $id not found');
    final next = current.isCompleted
        ? TaskStatus.outstanding
        : TaskStatus.completed;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            status: Value(next.name),
            updatedAt: Value(await _nextUpdatedAt(id)),
          ),
        );
    return (await byId(id))!;
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  /// Rewrites positions 0..n-1 following [ids], skipping ids that are not in
  /// the database. Rows not present in [ids] keep their current position, so
  /// a partial reorder is safe (ties are broken by `created_at` on read).
  Future<void> reorder(List<String> ids) async {
    await _db.transaction(() async {
      final rows = await _db.select(_db.tasks).get();
      final known = {for (final row in rows) row.id};
      var position = 0;
      for (final id in ids) {
        if (!known.contains(id)) continue;
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
              TasksCompanion(
                position: Value(position++),
                updatedAt: Value(utcNow()),
              ),
            );
      }
    });
  }

  /// All tasks sorted by position asc (created_at as tie-break).
  Future<List<Task>> all() async {
    final rows = await (_db.select(_db.tasks)
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return [for (final row in rows) _toTask(row)];
  }

  Task _toTask(dynamic row) => Task(
        id: row.id as String,
        title: row.title as String,
        status: TaskStatus.values.byName(row.status as String),
        dueDate: row.dueDate as DateTime?,
        position: row.position as int,
        createdAt: (row.createdAt as DateTime).toUtc(),
        updatedAt: (row.updatedAt as DateTime).toUtc(),
      );

  /// Epoch (millisecondsSinceEpoch == 0) means "no due date" (test contract);
  /// otherwise the local calendar date with any time-of-day stripped.
  static DateTime? _normalizeDueDate(DateTime? dueDate) {
    if (dueDate == null) return null;
    if (dueDate.millisecondsSinceEpoch == 0) return null;
    return calendarDate(dueDate);
  }

  /// Returns a timestamp strictly after the row's current `updated_at`, so
  /// every write visibly refreshes the audit field even when called within
  /// the same wall-clock second (drift stores UTC DateTimes at second
  /// precision by default, which would otherwise make two fast writes equal).
  Future<DateTime> _nextUpdatedAt(String id) async {
    final row = await (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final now = utcNow();
    if (row == null) return now;
    final current = (row.updatedAt as DateTime).toUtc();
    final nowSecond = now.millisecondsSinceEpoch ~/ 1000;
    final currentSecond = current.millisecondsSinceEpoch ~/ 1000;
    if (nowSecond > currentSecond) return now;
    return current.add(const Duration(seconds: 1));
  }
}