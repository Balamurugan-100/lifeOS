import 'package:drift/drift.dart';
import 'package:lifeos_core/lifeos_core.dart' show newId;
import 'package:lifeos_storage/lifeos_storage.dart' show utcNow;

import 'task_category.dart';
import 'task_database.dart';

/// Manages the editable list of task category names.
///
/// Tasks store their category as a *name* (see `task_category_table.dart` for
/// the reasoning), which shapes three behaviours here:
///
///  * [backfillFromTasks] lifts legacy free-text values into the registry so
///    upgrading users do not silently lose their categories.
///  * [update] with a new name rewrites the matching `tasks.category` values
///    in the same transaction, so a rename never orphans a task.
///  * [delete] refuses while tasks still use the category, surfacing
///    [TaskCategoryInUseException] rather than leaving dangling names.
///
/// Name uniqueness is enforced case-insensitively in Dart rather than with a
/// SQL unique index, because the table is soft-deleted: a unique index would
/// permanently reserve a name a user deleted.
class TaskCategoryRepository {
  TaskCategoryRepository(this._db);

  final TaskDatabase _db;

  /// All live categories, alphabetically by name.
  Future<List<TaskCategory>> all() async {
    final rows = await (_db.select(_db.taskCategories)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    return rows.map(_toCategory).toList();
  }

  Future<TaskCategory?> byId(String id) async {
    final row = await (_db.select(_db.taskCategories)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _toCategory(row);
  }

  /// Looks a category up by its name, case-insensitively.
  Future<TaskCategory?> byName(String name) async {
    final wanted = _clean(name).toLowerCase();
    if (wanted.isEmpty) return null;
    final rows = await (_db.select(_db.taskCategories)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    for (final row in rows) {
      if (row.name.toLowerCase() == wanted) return _toCategory(row);
    }
    return null;
  }

  /// Adds a category. Throws [TaskCategoryNameTakenException] when the name is
  /// already in use and `ArgumentError` when it is blank or over 40 chars.
  Future<TaskCategory> add(String name, {String? colorHex}) async {
    final clean = _clean(name);
    if (clean.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty');
    }
    if (clean.length > 40) {
      throw ArgumentError.value(
          name, 'name', 'Category name cannot exceed 40 characters');
    }
    if (await byName(clean) != null) {
      throw TaskCategoryNameTakenException(clean);
    }

    final id = newId();
    final now = utcNow();
    await _db.into(_db.taskCategories).insert(
          TaskCategoriesCompanion.insert(
            id: id,
            name: clean,
            colorHex: Value(colorHex ?? TaskCategory.defaultTaskCategoryColor),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return TaskCategory(id: id, name: clean, colorHex: colorHex ?? TaskCategory.defaultTaskCategoryColor, createdAt: now);
  }

  /// Renames and/or recolours a category.
  ///
  /// Renaming also rewrites every live task carrying the old name, in one
  /// transaction — otherwise the tasks would be left referencing a name that no
  /// longer exists in the registry.
  Future<TaskCategory> update(
    String id, {
    String? name,
    String? colorHex,
  }) async {
    final current = await byId(id);
    if (current == null) {
      throw StateError('No task category with id "$id".');
    }

    final clean = name == null ? current.name : _clean(name);
    if (clean.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty');
    }
    if (clean.length > 40) {
      throw ArgumentError.value(
          name, 'name', 'Category name cannot exceed 40 characters');
    }
    if (clean.toLowerCase() != current.name.toLowerCase()) {
      final clash = await byName(clean);
      if (clash != null && clash.id != id) {
        throw TaskCategoryNameTakenException(clean);
      }
    }

    final nextColor = colorHex ?? current.colorHex;
    final now = utcNow();
    await _db.transaction(() async {
      await (_db.update(_db.taskCategories)..where((t) => t.id.equals(id)))
          .write(
        TaskCategoriesCompanion(
          name: Value(clean),
          colorHex: Value(nextColor),
          updatedAt: Value(now),
        ),
      );
      if (clean != current.name) {
        await (_db.update(_db.tasks)
              ..where((t) =>
                  t.category.equals(current.name) & t.deletedAt.isNull()))
            .write(TasksCompanion(
          category: Value(clean),
          updatedAt: Value(now),
        ));
      }
    });

    return current.copyWith(
      name: clean,
      colorHex: nextColor,
      updatedAt: now,
    );
  }

  /// Soft-deletes a category.
  ///
  /// Throws [TaskCategoryInUseException] while any live task still carries the
  /// name. A soft delete (rather than a hard one) means the row stays visible
  /// in the audit trail, and the name is immediately reusable because [all]
  /// filters on `deleted_at IS NULL`.
  Future<void> delete(String id) async {
    final current = await byId(id);
    if (current == null) return;

    final inUse = await taskCountIn(current.name);
    if (inUse > 0) {
      throw TaskCategoryInUseException(current.name, inUse);
    }

    final now = utcNow();
    await (_db.update(_db.taskCategories)..where((t) => t.id.equals(id))).write(
      TaskCategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// How many live tasks currently carry [name].
  Future<int> taskCountIn(String name) async {
    final clean = _clean(name);
    if (clean.isEmpty) return 0;
    final count = _db.tasks.id.count();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([count])
      ..where(_db.tasks.category.equals(clean) & _db.tasks.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Every live category with a live task count, alphabetically by name.
  ///
  /// Backs the manage screen, which shows "used by N" next to each entry.
  Future<List<({TaskCategory category, int taskCount})>> allWithUsage() async {
    final categories = await all();
    final result = <({TaskCategory category, int taskCount})>[];
    for (final category in categories) {
      result.add((category: category, taskCount: await taskCountIn(category.name)));
    }
    return result;
  }

  /// Lifts distinct legacy `tasks.category` values into the registry.
  ///
  /// Categories used to be typed free-form, so an existing install can hold
  /// names the registry has never seen. This is idempotent (names already
  /// present are skipped) and returns the categories it created, so a caller
  /// can log what was migrated.
  Future<List<TaskCategory>> backfillFromTasks() async {
    final rows = await (_db.selectOnly(_db.tasks)
          ..addColumns([_db.tasks.category])
          ..where(_db.tasks.category.isNotNull() &
              _db.tasks.deletedAt.isNull())
          ..groupBy([_db.tasks.category]))
        .get();

    final existing = {
      for (final c in await all()) c.name.toLowerCase(),
    };

    final created = <TaskCategory>[];
    for (final row in rows) {
      final name = _clean(row.read(_db.tasks.category) ?? '');
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!existing.add(key)) continue;
      created.add(await add(name));
    }
    return created;
  }

  TaskCategory _toCategory(dynamic row) => TaskCategory(
        id: row.id as String,
        name: row.name as String,
        colorHex: row.colorHex as String,
        createdAt: row.createdAt as DateTime,
        updatedAt: row.updatedAt as DateTime?,
        deletedAt: row.deletedAt as DateTime?,
      );

  static String _clean(String value) => value.trim();
}
