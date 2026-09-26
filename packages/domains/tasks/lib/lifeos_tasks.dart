/// LifeOS Tasks domain package.
///
/// Task lifecycle (add/edit/complete/delete), manual ordering, optional due
/// dates, tracked work sessions (stopwatch + Pomodoro), and the home summary
/// contribution (see contracts in specs/001-lifeos-foundation).
library lifeos_tasks;

export 'src/pomodoro.dart';
export 'src/task.dart';
export 'src/task_category.dart';
export 'src/task_category_repository.dart';
export 'src/task_database.dart' hide Task, TimeSession, TaskCategoryEntry;
export 'src/task_repository.dart';
export 'src/task_summary.dart';
export 'src/time_repository.dart';
export 'src/time_session.dart';
export 'tasks_module.dart';