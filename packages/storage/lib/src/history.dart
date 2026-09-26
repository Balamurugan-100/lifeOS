import 'package:drift/drift.dart';

/// Audit fields added to every persistable LifeOS table (data-model.md):
/// UTC created/updated timestamps that keep the future sync door open.
///
/// Repositories set both values explicitly on insert and refresh
/// [updatedAt] on every write (constitution Principle III).
mixin AuditFields on Table {
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();
}

/// Current UTC instant (audit timestamps are UTC per data-model.md).
DateTime utcNow() => DateTime.now().toUtc();