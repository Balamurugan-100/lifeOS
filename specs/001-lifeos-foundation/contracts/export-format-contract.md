# Contract: ExportEnvelope — one-tap portable export

**Requirements**: FR-013, SC-009 (one action, complete, readable, movable
off-device), edge case (failure leaves data untouched and is retryable).

## Shape (JSON)

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-09-22T12:00:00Z",
  "appVersion": "0.1.0",
  "domains": {
    "tasks":  { "tasks": [ { "id": "...", "title": "...", "dueDate": "2026-09-30", "status": "outstanding", "position": 1, "createdAt": "...", "updatedAt": "..." } ] },
    "habits": { "habits": [ { "id": "...", "name": "...", "schedule": { "type": "weekly", "daysOfWeek": [1, 3, 5] } } ],
                "entries": [ { "id": "...", "habitId": "...", "date": "2026-09-18", "completedAt": "..." } ] }
  }
}
```

## Rules

1. **Completeness (SC-009)**: the envelope MUST contain every record the
   user owns, including records in disabled domains (disable ≠ delete).
2. **Readability**: plain JSON, no binary encoding; field names are stable
   and match the data model ([data-model.md](../data-model.md)).
3. **One action (FR-013)**: the full export is produced and offered through
   the device share sheet in a single user action.
4. **Versions**: `schemaVersion` increments only for breaking changes;
   additive fields (new domains, new columns) DO NOT change it but MUST be
   documented in the domain payload. Consumers read unknown fields
   tolerantly.
5. **Failure safety**: if export fails (e.g., storage full), no data is
   modified, the user is notified, and the action can be retried.
6. **Future import/sync**: v1 is export-only. A future sync/importer MUST be
   able to parse this envelope without changes; audit timestamps (UTC) and
   UUID ids are preserved for that purpose (Principle III / research D-5).

## Evolution

- New domains append their own `domains.<key>` payload — additive.
- Renaming a persisted field is breaking: bump `schemaVersion` and document
  the migration under the contract versioning procedure in
  [README.md](README.md).