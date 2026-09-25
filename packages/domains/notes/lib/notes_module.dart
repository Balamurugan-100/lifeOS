import 'package:lifeos_core/lifeos_core.dart'
    show DomainSummary, HighlightedItem, ModuleDescriptor;

import 'src/database/note_database.dart';
import 'src/notes_summary.dart';
import 'src/repositories/notes_repository.dart';

class NotesModule extends ModuleDescriptor {
  NotesModule(NoteDatabase database) : _repository = NotesRepository(database);

  final NotesRepository _repository;
  late final NotesSummaryBuilder _builder = NotesSummaryBuilder(_repository);

  @override
  String get key => 'notes';

  @override
  String get name => 'Markdown Notes';

  @override
  Future<DomainSummary> buildSummary() => _builder.build();

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return false;
  }
}
