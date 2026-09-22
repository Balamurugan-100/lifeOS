# Data Model: LifeOS Foundation

Derived from the feature spec's Key Entities and clarified requirements.
Modeling conventions (R-1..R-5 in [research.md](research.md)): UUID v4 ids,
local calendar dates for due-dates/habit days, UTC timestamps for audit
fields, drift-typed SQLite tables compiled from these definitions.

## Conventions

- **Ids**: UUID v4 strings everywhere (`id TEXT`). Collision-safe for future
  multi-device sync.
- **Dates vs timestamps**: `Date` = calendar date in the user's local
  timezone (no clock time). `DateTime` = UTC instant for audit fields only.
- **Audit fields**: every persistable entity carries `created_at` and
  `updated_at` (UTC). `updated_at` is refreshed on every write; this is the
  future conflict-resolution hook — no sync logic in v1.
- **Naming**: tables named after the entity; unit records singular, e.g.
  `task`, `habit`, `habit_entry`; the domain package exposes immutable Dart
  models with the same fields.

## Entities

### 1. DomainModule

The installed, independently functioning domain (e.g., Tasks, Habits).

| Field | Type | Notes |
|-------|------|-------|
| key | String | stable identifier: `tasks`, `habits`; used in registry and contracts |
| name | String | display name ("Tasks", "Habits") |
| enabled | bool | toggled by the user; disabling never deletes domain data (FR-005) |
| sortOrder | int | home display order; default registry order |

Relationships: a module exposes zero or more summary contributions to Home.
Domains are stored/derived from the registry in `core` (module packages
declare their `ModuleDescriptor`); persistence of enabled state lives in the
app shell's settings table.

State transitions: `enabled=false → true` (re-enable, prior data intact);
`enabled=true → false` (disable; data retained, not queried for home).

### 2. Task

An item in the Tasks domain (FR-010).

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | |
| title | String | non-empty; trimmed; max 200 chars |
| dueDate | Date? | optional; null = undated (never overdue, "undated area" of list/home) |
| status | enum {outstanding, completed} | overdue is derived, not stored |
| position | int | manual ordering within the task list |
| createdAt | DateTime (UTC) | |
| updatedAt | DateTime (UTC) | |

Validation: `title` required (1–200 chars after trim); `status` ∈ {outstanding,
completed}; `position` non-negative.

State transitions:

```
outstanding ──(mark complete)──> completed
completed   ──(undo)──────────> outstanding   // idempotent toggle; no duplicates
```
Derived state: a task is shown as **overdue** when `status = outstanding` and
`dueDate < today` (local calendar date). Toggling is safe to invoke repeatedly
(mark complete twice = no-op on the second call).

### 3. Habit

A behavior the user repeats on a preset schedule (FR-011, clarification Q4).

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | |
| name | String | non-empty; trimmed; max 100 chars |
| schedule | enum {daily} or {weekly, daysOfWeek: Set<1..7>} | preset only; no freeform recurrence |
| createdAt | DateTime (UTC) | |
| updatedAt | DateTime (UTC) | |

Validation: `name` required (1–100 chars); `weekly` schedules must include at
least one weekday; `daily` carries no day set.

State transitions: none beyond create/rename/delete — a habit is a definition;
state lives in its entries.

### 4. HabitEntry

A recorded completion of a habit on a specific day (FR-011).

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | |
| habitId | String (UUID) | FK → Habit.id |
| date | Date | scheduled day the entry belongs to |
| completedAt | DateTime (UTC) | when the entry was recorded |
| createdAt | DateTime (UTC) | |

Uniqueness: **one entry per (habitId, date)** — enforced by a composite unique
constraint. Recording today twice is idempotent; un-recording removes the row.

State transitions:

```
absent ──(record)──> present (completed)
present ──(un-record)──> absent
```

Streak & history are **derived** (computed by `streak.dart`) from present
entries on scheduled days only: for `daily`, every date from the habit's
start; for `weekly`, only the selected weekdays count as "scheduled". Days
that are not scheduled never count as missed (edge case added in
clarification).

### 5. SummaryContribution (a.k.a. DomainSummary)

The typed contract every enabled domain exposes to Home (FR-001, FR-007);
defined in `core` (see [contracts/domain-summary-contract.md](contracts/domain-summary-contract.md)).

| Field | Type | Notes |
|-------|------|-------|
| domainKey | String | module key (`tasks`, `habits`) |
| displayName | String | human name |
| counts | Map<String, int> | semantic per-domain counts, e.g. tasks: `outstanding`, `overdue`, `completedToday`; habits: `streaksActive`, `doneToday` |
| highlighted | List<HighlightedItem> | actionable items for home (next due task, overdue tasks, today's habits) |
| refreshedAt | DateTime (UTC) | when the summary was computed |

### 6. HighlightedItem

An actionable entry inside a domain summary (FR-001, SC-007).

| Field | Type | Notes |
|-------|------|-------|
| id | String | stable item reference (task/habit id) |
| kind | String | semantic kind, e.g. `task.due`, `task.overdue`, `habit.today` |
| title | String | short display text |
| subtitle | String? | optional context (due date, streak) |
| action | enum {complete, openDomain} | what "tap" does; `complete` allowed only when direct action is safe (SC-007) |

### 7. HomeSnapshot

The assembled home view (read model), not persisted (recomputed on return to
home per FR-003).

| Field | Type | Notes |
|-------|------|-------|
| summaries | List<SummaryContribution> | one per enabled domain |
| empty | bool | true when no enabled domain has data (FR-004 empty state) |

### 8. ExportEnvelope

The portable, one-tap export artifact (FR-013, SC-009); format contract in
[contracts/export-format-contract.md](contracts/export-format-contract.md).

| Field | Type | Notes |
|-------|------|-------|
| schemaVersion | int | 1 for v1; additive changes bump this |
| exportedAt | DateTime (UTC) | |
| appVersion | String | LifeOS version at export time |
| domains | Map<domainKey, payload> | e.g. `tasks: {tasks: [...]}`, `habits: {habits, entries: [...]}` |

Export must contain every record the user owns (SC-009). Failure must not
modify data and must be retryable (edge case).

## Relationships (summary)

```text
DomainModule 1───* SummaryContribution ──1 HomeSnapshot
Task                (no FKs; standalone)
Habit 1───* HabitEntry          (FK: habit_id)
Habit 1───* SummaryContribution (via its module)
ExportEnvelope 1───* DomainPayload (flat serialization of tables above)
```

## Derivation rules (test targets)

- Task **overdue** = `status = outstanding ∧ dueDate < today`.
- Habit **streak** (daily) = consecutive present entries ending today or
  yesterday, counting from first record; (weekly) = consecutive scheduled
  weeks with a present entry, unscheduled days ignored.
- Home **highlighting** priority (per domain) = overdue first, then nearest
  due, then today's habits.
- **Freshness** (SC-002) = HomeSnapshot is recomputed on every return to home;
  no caches persist across navigation.