import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor, todayLocal;

import 'src/habit_database.dart';
import 'src/habit_repository.dart';
import 'src/habit_summary.dart';

/// The Habits domain's [ModuleDescriptor] (domain-module-contract.md).
///
/// Exposes the home summary and handles the direct `habit.today` complete
/// action. Other kinds are not consumed (returns false so the caller can fall
/// back to opening the domain).
class HabitsModule extends ModuleDescriptor {
  HabitsModule(HabitDatabase database) : _repository = HabitRepository(database);

  final HabitRepository _repository;
  late final HabitSummaryBuilder _builder = HabitSummaryBuilder(_repository);

  @override
  String get key => 'habits';

  @override
  String get name => 'Habits';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    if (item.kind != 'habit.today') return false;
    final habit = await _repository.byId(item.id);
    if (habit == null) return false;
    await _repository.record(habit.id, todayLocal());
    return true;
  }
}