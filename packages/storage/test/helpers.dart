import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart';

/// Hermetic in-memory drift executor for domain repository tests
/// (research D-8). Each call returns a fresh empty database.
QueryExecutor inMemory() => openInMemoryExecutor();

/// Opens an in-memory executor and closes it after [body] completes,
/// guaranteeing no state leaks between tests.
Future<T> withDatabase<T>(Future<T> Function(QueryExecutor executor) body) async {
  final executor = inMemory();
  try {
    return await body(executor);
  } finally {
    await closeExecutor(executor);
  }
}