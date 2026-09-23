/// LifeOS Tasks domain package.
///
/// Task lifecycle (add/edit/complete/delete), manual ordering, optional due
/// dates, and the home summary contribution (see contracts in
/// specs/001-lifeos-foundation).
library lifeos_tasks;

export 'src/task.dart';
export 'src/task_database.dart' hide Task;
export 'src/task_repository.dart';
export 'src/task_summary.dart';
export 'tasks_module.dart';