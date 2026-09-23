import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/task_database.dart';
import 'src/task_repository.dart';
import 'src/task_summary.dart';

/// The Tasks domain's [ModuleDescriptor] (domain-module-contract.md).
///
/// Exposes the home summary and handles the direct `task.overdue` /
/// `task.due` complete action. Other kinds are not consumed (returns false so
/// the caller can fall back to opening the domain).
class TasksModule extends ModuleDescriptor {
  TasksModule(TaskDatabase database) : _repository = TaskRepository(database);

  final TaskRepository _repository;
  late final TaskSummaryBuilder _builder = TaskSummaryBuilder(_repository);

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