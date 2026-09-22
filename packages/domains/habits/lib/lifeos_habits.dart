/// LifeOS Habits domain package.
///
/// Preset daily/weekly schedules, per-day completion entries, streak
/// derivation, and the home summary contribution (see contracts in
/// specs/001-lifeos-foundation).
library lifeos_habits;

export 'src/habit.dart';
export 'src/habit_database.dart' hide Habit, HabitEntry;
export 'src/habit_repository.dart';
export 'src/streak.dart';
export 'src/habit_summary.dart';
export 'habits_module.dart';