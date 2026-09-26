import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/task_database.dart';
import 'src/task_repository.dart';
import 'src/task_summary.dart';
import 'src/time_repository.dart';

/// The Tasks domain's [ModuleDescriptor] (domain-module-contract.md).
///
/// Exposes the home summary (including tracked time today) and handles the
/// direct `task.overdue` / `task.due` complete action. Other kinds are not
/// consumed (returns false so the caller can fall back to opening the domain).
class TasksModule extends ModuleDescriptor {
  TasksModule(TaskDatabase database)
      : _repository = TaskRepository(database),
        _time = TimeRepository(database);

  final TaskRepository _repository;
  final TimeRepository _time;
  late final TaskSummaryBuilder _builder =
      TaskSummaryBuilder(_repository, _time);

  @override
  String get key => 'tasks';

  @override
  String get name => 'Tasks';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    if (item.kind != 'task.overdue' && item.kind != 'task.due') return false;
    final task = await _repository.byId(item.id);
    if (task == null || task.isCompleted) return false;
    await _repository.toggle(item.id);
    return true;
  }
}