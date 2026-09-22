import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the app's single SQLite database on the device (FR-008/FR-009:
/// everything lives on the device, no network).
///
/// The connection is shared by every domain database via
/// `databaseExecutorProvider` (T017). `migrateToLatest` is the v1
/// cross-domain no-op registered in `lifeos_storage`.
Future<QueryExecutor> openAppDatabase() async {
  final documents = await getApplicationDocumentsDirectory();
  final dbPath = p.join(documents.path, 'lifeos.db');
  return openFileExecutor(dbPath);
}