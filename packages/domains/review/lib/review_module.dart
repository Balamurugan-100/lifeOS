import 'package:lifeos_core/lifeos_core.dart';
import 'src/repositories/review_repository.dart';
import 'src/review_summary.dart';

class ReviewModule extends ModuleDescriptor {
  ReviewModule(this._repo);

  final ReviewRepository _repo;

  @override
  String get key => 'review';

  @override
  String get name => 'Weekly Review';

  @override
  Future<DomainSummary> buildSummary() {
    return ReviewSummaryBuilder(_repo).build();
  }

  @override
  Future<bool> handleAction(HighlightedItem item) async {
    return true;
  }
}
