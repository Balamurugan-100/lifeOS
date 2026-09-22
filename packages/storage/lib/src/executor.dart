import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart' show NativeDatabase;

/// Opens a drift query executor backed by the SQLite file at [databasePath].
///
/// Used by the app shell to own a single connection for all domain packages
/// (local-first: everything lives on the device, FR-008/FR-009).
QueryExecutor openFileExecutor(String databasePath) {
  return NativeDatabase(File(databasePath));
}

/// Opens an in-memory drift executor for hermetic repository tests
/// (research D-8).
QueryExecutor openInMemoryExecutor() => NativeDatabase.memory();

/// Closes [executor] and releases the underlying connection.
Future<void> closeExecutor(QueryExecutor executor) => executor.close();