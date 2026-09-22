/// The storage schema-version ledger and migration scaffold (T014).
///
/// LifeOS v1 keeps each domain's tables in its owning package (`tasks`,
/// `habits`), each a drift `Database` with its own schema version, sharing
/// the single [QueryExecutor] opened via `executor.dart`. This file is the
/// combined storage contract: it records the overall schema version and is
/// where future cross-domain migrations (or a unified `AppDatabase`) register.
library;

import 'package:drift/drift.dart';

/// Combined storage schema version. Bumped for breaking cross-domain layout
/// changes; per-domain databases version themselves independently.
const int storageSchemaVersion = 1;

/// Runs any pending cross-domain migrations against [executor].
///
/// v1 has none: each domain drift database creates its own tables on first
/// open and manages its own [Database.schemaVersion]. Called from the app
/// bootstrap before domain databases are opened (currently a no-op scaffold,
/// per data-model.md audit-field conventions).
Future<void> migrateToLatest(QueryExecutor executor) async {
  // v1: no cross-domain migrations.
}