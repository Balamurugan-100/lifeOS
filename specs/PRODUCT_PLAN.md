# LifeOS — Product & Implementation Plan

> Status: Living roadmap
> Scope: Extend the existing LifeOS implementation without rebuilding existing domains.
> Primary principle: local-first, offline-capable, future-sync-ready.
>
> The repository already contains implementations/packages for Tasks, Habits, Finance,
> Journal, Focus, Goals, Notes, Gamification, Rituals, Planner, Wellness and Review,
> plus local persistence, export and notifications. This plan therefore focuses on
> improving, connecting and extending what exists rather than restarting from a
> foundation-only roadmap.

---

## 1. Product Direction

LifeOS is a personal operating system for one person.

The product should answer four questions:

1. **What is happening in my life?**
2. **What should I do now?**
3. **How am I actually doing?**
4. **What patterns can I learn from my own data?**

The core loop is:

```text
OBSERVE
  ↓
CAPTURE
  ↓
ACT
  ↓
REVIEW
  ↓
UNDERSTAND
  ↓
ADJUST
```

The app must not become a collection of disconnected CRUD trackers.

### Product rule

Every feature must do at least one of:

- reduce manual tracking;
- improve understanding of existing data;
- help the user take an action;
- preserve useful historical data for future analysis.

If a feature does none of these, defer it.

---

# 2. Non-Negotiable Architecture Principles

## 2.1 Local-first

All primary user data lives on-device.

```text
UI
 ↓
Domain
 ↓
Repository
 ↓
SQLite / Drift
```

There is no required backend, account, cloud database or network connection.

The application must remain fully usable in airplane mode.

## 2.2 Future synchronization

Do not build sync now.

But every persistent record must be designed so a future sync layer can be added without redesigning the domain.

Persistent entities should use:

```text
id
createdAt
updatedAt
deletedAt (nullable, when tombstones are required)
```

Use stable UUIDs rather than database-generated sequential IDs for user-owned entities.

Do not use server IDs as the primary local identity.

Future architecture:

```text
                 Domain Repository
                        │
              ┌─────────┴─────────┐
              ↓                   ↓
        Local Storage        Sync Adapter
                                  ↓
                         Remote / Self-hosted
```

The domain must not know whether sync exists.

## 2.3 Domain autonomy

Existing domains remain independently usable.

Domains must not import UI code or depend on the Home screen.

Home consumes domain summaries.

Cross-domain analytics should operate through explicit contracts/read models rather than direct access to another domain's internal tables.

## 2.4 Export remains mandatory

Portable export is the emergency backup and future migration mechanism.

Every new domain must be included in export.

Export must be schema-versioned and readable without LifeOS.

---

# 3. Existing Feature Baseline

The repository currently has these domain packages:

- Tasks
- Habits
- Finance
- Journal
- Focus
- Goals
- Notes
- Gamification
- Rituals
- Planner
- Wellness
- Review

The application also has:

- Home overview
- Local SQLite/Drift persistence
- Domain registration
- Portable export
- Local notifications
- Android/iOS targets
- Integration/unit/widget testing

Do not recreate these domains.

The next work should be organized around their quality and relationships.

---

# 4. Priority Model

| Priority | Meaning |
|---|---|
| P0 | Required for LifeOS core quality |
| P1 | High-value feature that directly improves daily use |
| P2 | Valuable extension after P0/P1 |
| P3 | Experimental / only after enough real data |
| Deferred | Explicitly do not build yet |

---

# 5. P0 — Foundation Hardening

Before adding significant new functionality, make the existing system robust.

## 5.1 Data metadata

Audit every domain and ensure persistent records have:

- stable UUID
- createdAt
- updatedAt
- optional deletedAt where future sync/tombstones require it
- source/provenance where data may come from external systems

Do not add generic metadata fields that are not useful.

## 5.2 Database migrations

Every schema change must have an explicit Drift migration.

Test:

- fresh install;
- upgrade from previous schema;
- data survives migration;
- migration is idempotent;
- corrupted/partial migration fails safely.

## 5.3 Repository boundaries

Each domain should expose repository operations rather than allowing UI code to query Drift tables directly.

## 5.4 Export

Extend export for every domain.

Export envelope:

```text
schemaVersion
exportedAt
appVersion
domains
```

Each domain contributes its own payload.

Do not make export depend on a future server.

## 5.5 Data deletion

Every domain needs a clear deletion strategy.

For sync-readiness, prefer tombstones where permanent deletion would otherwise cause resurrection during future synchronization.

Do not expose sync-specific UI yet.

---

# 6. P0 — Existing Domains: Improve Instead of Rebuild

## 6.1 Tasks — KEEP + IMPROVE

Existing task lifecycle remains the foundation.

### Keep

- create
- edit
- complete
- delete
- ordering
- optional due date
- overdue calculation

### Add incrementally

P1:
- priority
- tags
- task notes
- recurring tasks
- subtasks

P2:
- projects
- dependencies
- estimated duration
- task history

### Important rule

Do not turn Tasks into a project-management product.

Tasks should represent actionable work.

---

# 7. P0 — Habits: KEEP + CONNECT

Existing habit scheduling, history and streak concepts remain.

### Improve

- daily/weekly completion statistics
- completion percentage
- streak history
- missed vs unscheduled days
- monthly trend
- habit reliability

### Do not prioritize

- XP
- coins
- leaderboards
- achievement spam

Gamification must remain optional and subordinate to actual behavioral history.

---

# 8. P1 — Goals: CONNECT TO EXECUTION

Goals should not be another isolated tracker.

Model:

```text
Goal
 ↓
Supporting habits
 ↓
Supporting tasks
 ↓
Actual execution
```

### Goal data

```text
id
title
description
status
startDate
targetDate
createdAt
updatedAt
```

Optional later:

```text
targetValue
currentValue
unit
```

### Goal dashboard

Show:

- progress;
- deadline;
- related tasks;
- related habits;
- recent activity;
- blockers.

Avoid pretending that every goal can be reduced to a percentage.

---

# 9. P1 — Quick Capture

Add a universal capture flow.

The user should not have to decide the destination first.

Examples:

```text
"Buy running shoes"
        ↓
Task

"Interesting idea for LifeOS sync"
        ↓
Note

"Today was productive"
        ↓
Journal

"Need to call bank tomorrow"
        ↓
Task
```

### Requirements

- one-tap entry;
- fast text input;
- optional destination;
- allow inbox/uncategorized state;
- later classification.

Quick Capture should be optimized for speed, not configuration.

---

# 10. P1 — Journal

Keep Journal lightweight.

### Core data

```text
JournalEntry
├── id
├── text
├── createdAt
├── updatedAt
└── optional tags / mood
```

Do not make Journal a second Notes system.

### Journal should feed

- Review
- personal analytics
- timeline
- future AI insights

---

# 11. P1 — Notes

Keep Notes deliberately smaller than Notion.

Notes answer:

> What information do I want to remember?

Journal answers:

> What happened / what was I thinking?

Do not build:

- databases inside notes;
- collaborative editing;
- complex page builders;
- full project-management features.

---

# 12. P1 — Focus

Focus should become the bridge between planning and actual execution.

### Focus session

```text
FocusSession
├── id
├── startedAt
├── endedAt
├── duration
├── taskId (nullable)
├── interruptionCount
└── completion state
```

### Metrics

- focus time/day;
- focus time/week;
- sessions completed;
- interruptions;
- focus time by task;
- focus time by category.

### Later

- Android foreground notification;
- lock-screen controls;
- widget;
- automatic task association.

---

# 13. P1 — Planner

Planner should NOT create a second task database.

It consumes:

```text
Tasks
Habits
Goals
Calendar
Focus availability
```

and produces:

```text
Today's plan
```

### Planner responsibilities

- show today's schedule;
- show available time;
- surface overdue/high-priority tasks;
- reserve focus blocks;
- show habits due today;
- respect calendar conflicts.

### Do not build yet

- Gantt charts;
- resource allocation;
- complex project scheduling;
- enterprise project management.

---

# 14. P1 — Review

Review should become a major LifeOS feature.

## Daily review

Show:

- completed tasks;
- incomplete tasks;
- habits;
- focus time;
- journal entries;
- expenses;
- wellness data where available.

## Weekly review

Show:

```text
Tasks
Habits
Focus
Sleep
Activity
Expenses
Goals
Journal
```

Compare current week against previous periods.

The Review domain should eventually become the main bridge into analytics.

---

# 15. P1 — Notifications

Keep local notifications.

Do not notify users merely to increase engagement.

Good:

```text
Your focus block starts in 5 minutes.
```

Good:

```text
You have 30 minutes free before your next meeting.
```

Bad:

```text
You haven't opened LifeOS today.
```

Notifications should be:

- actionable;
- contextual;
- dismissible;
- locally generated;
- based on user-defined preferences.

---

# 16. P1 — Wellness: Convert to a Data Consumer

Wellness should not try to invent health data.

The Android implementation should use Health Connect as an external data source.

LifeOS stores its own normalized local copy for historical analysis.

Architecture:

```text
Health Connect
      ↓
Health Connect Adapter
      ↓
Normalization
      ↓
Local Wellness DB
      ↓
Wellness Domain
      ↓
Home / Review / Analytics
```

---

# 17. Health Connect — Android Plan

## 17.1 Goal

Import health/activity data that already exists on the user's Android device or connected health applications.

LifeOS does NOT need to detect sleep itself when another device/app has already recorded it.

Example:

```text
Galaxy Watch / other wearable
          ↓
      Health app
          ↓
    Health Connect
          ↓
       LifeOS
```

If no wearable/app provides sleep data, LifeOS should not pretend to have accurate automatic sleep detection.

Phone-only sleep inference is deferred.

---

# 18. Health Connect Phase A — Read-Only Integration

Start with READ permissions only.

Do not request WRITE permissions unless LifeOS later becomes an actual health-data recorder.

### Initial data types

Implement in this order:

1. Sleep sessions
2. Steps
3. Total calories burned / activity calories where available
4. Exercise sessions
5. Heart rate
6. Resting heart rate
7. Respiratory rate
8. Oxygen saturation

Only add additional data types when the UI has a clear use for them.

Do not request every Health Connect permission up front.

---

# 19. Health Connect Sleep

Use:

```text
SleepSessionRecord
```

Health Connect sleep sessions contain:

- start time;
- end time;
- sleep stages when available.

Supported stages include:

- UNKNOWN
- AWAKE
- SLEEPING
- OUT_OF_BED
- AWAKE_IN_BED
- LIGHT
- DEEP
- REM

LifeOS should treat sleep stages as optional.

Not every source will provide all stages.

### Local normalized model

```text
SleepSession
├── id
├── source
├── sourceRecordId
├── startAt
├── endAt
├── duration
├── stages[]
├── importedAt
└── updatedAt
```

Stage:

```text
SleepStage
├── type
├── startAt
└── endAt
```

Do not assume one sleep session equals one calendar day.

A session can cross midnight.

---

# 20. Health Connect Provenance

Every imported health record needs source information.

Example:

```text
source = health_connect
sourceApp = package/data origin
sourceRecordId = Health Connect record id
importedAt = local import timestamp
```

This is important for:

- deduplication;
- debugging;
- re-import;
- future sync;
- showing the user where a value came from.

Never blindly insert the same Health Connect record every time the app opens.

---

# 21. Health Connect Sync Strategy

There are two different meanings of "sync":

### External ingestion

```text
Health Connect → LifeOS
```

This is required for the feature.

### Cloud synchronization

```text
LifeOS local DB ↔ remote server
```

This is NOT required now.

Keep them separate.

The Health Connect adapter should only know:

```text
read records
normalize records
persist locally
```

It must not know anything about a future LifeOS server.

---

# 22. Health Connect Permissions

Create a dedicated settings screen:

```text
Health
────────────────────

Health Connect
Connected

Sleep          ✓
Steps          ✓
Exercise       ✓
Heart rate     ✓
Respiratory    ✓
SpO₂           ✕

[Manage access]
[Sync now]
```

Users can revoke permissions at any time.

LifeOS must check permission state before reading.

If access is revoked:

- do not crash;
- do not repeatedly request permission;
- show a clear state;
- provide a Manage Access action.

---

# 23. Health Connect Import Strategy

Use an incremental import strategy.

Do not scan the entire Health Connect database every time the app opens.

Maintain:

```text
HealthImportState
├── dataType
├── lastSuccessfulReadAt
├── lastAttemptAt
└── status
```

Then query a bounded time range.

For first installation:

```text
Initial import:
recent historical window
```

For subsequent imports:

```text
last successful import → now
```

Also provide:

```text
Sync last 30 days
Sync last 90 days
Sync all available history
```

only when technically appropriate for the data type and Health Connect access rules.

---

# 24. Health Connect Background Reads

Do not make continuous background collection the first version.

Start with:

- foreground sync;
- manual "Sync now";
- sync on relevant app lifecycle events.

Then evaluate background reads.

If background reads are added:

- use Android-supported background access;
- use WorkManager for deferred synchronization;
- avoid waking the device unnecessarily;
- batch imports;
- avoid polling every few minutes.

The goal is low battery impact.

---

# 25. Health Connect Data Normalization

External data must be normalized before entering the Wellness domain.

Example:

```text
Health Connect Record
        ↓
ExternalHealthRecord
        ↓
Normalizer
        ↓
Wellness model
```

Never let the rest of LifeOS depend directly on Health Connect record classes.

This makes future integrations possible:

```text
Health Connect
Apple Health
Fitbit API
Garmin
Manual entry
CSV import
        ↓
Common Wellness model
```

Only Android Health Connect is implemented initially.

---

# 26. Health Connect Home Summary

Do not put every health metric on Home.

Home should show only high-value context.

Example:

```text
Wellness

Sleep       7h 12m
Steps       6,420
Activity    38m
```

Optional later:

```text
Sleep
↓ 42m from baseline
```

Do not turn Home into a medical dashboard.

---

# 27. P2 — Finance

Keep the existing Finance implementation.

Improve it around actual personal usefulness.

### Core

```text
Expense
├── id
├── amount
├── category
├── timestamp
├── note
└── accountId?
```

Later:

- income;
- accounts;
- recurring expenses;
- budgets;
- monthly summaries;
- net worth.

Do not build bank integrations yet.

Manual/local finance keeps the system private and simple.

---

# 28. P2 — Rituals

Keep Rituals if it represents a meaningful sequence of actions.

Use it for:

```text
Morning routine
Evening shutdown
Workout preparation
Weekly review
```

Rituals can orchestrate existing:

- habits;
- tasks;
- focus;
- journal prompts.

Do not duplicate the underlying data.

---

# 29. P2 — Gamification

Keep the domain only if it motivates actual behavior.

Recommended:

- streaks;
- progress;
- consistency;
- milestones.

Avoid:

- artificial currency;
- leaderboards;
- competitive rankings;
- excessive badges;
- XP inflation.

Gamification must never become the primary reason to use LifeOS.

---

# 30. P2 — Timeline

Add a unified local timeline.

Sources:

```text
Task completed
Habit completed
Focus session
Journal entry
Expense
Workout
Sleep
Calendar event
Goal progress
```

Example:

```text
Today

07:10  Wake
07:35  Habit: Walk ✓
08:20  Sleep imported: 7h 12m
09:30  Focus: API work
11:00  Meeting
13:20  Expense: Lunch
15:00  Task completed
18:30  Workout
```

This may become one of the most useful LifeOS screens.

---

# 31. P2 — Baseline Engine

After enough historical data exists, calculate personal baselines.

Examples:

```text
Average sleep
Median sleep
Average focus time
Average task completion
Average daily expenses
Average steps
Average meeting hours
Habit completion rate
```

Prefer robust statistics such as median and rolling averages where appropriate.

Do not claim causation from correlations.

---

# 32. P2 — Cross-Domain Analytics

Build analytics only after data exists.

Examples:

```text
Sleep ↔ Task completion
Sleep ↔ Focus time
Meetings ↔ Focus time
Exercise ↔ Mood
Habits ↔ Goal progress
Spending ↔ Categories
```

Use simple statistics first.

No AI required.

Analytics should say:

```text
"On days where X happened, Y was different."
```

not:

```text
"X caused Y."
```

---

# 33. P3 — Insight Engine

The insight engine consumes existing domain summaries and historical analytics.

Example:

```text
Insight

Your focus time is 23% lower this week.

Possible related changes:
• Sleep is down 41 minutes/day.
• Meeting time is up 2h 10m.
• Planned tasks are up 18%.
```

Insights must show evidence.

Avoid unsupported recommendations.

---

# 34. P3 — AI

AI should be an optional layer on top of LifeOS data.

Do NOT make:

```text
Chatbot = LifeOS
```

Instead:

```text
LifeOS data
     ↓
Statistics
     ↓
Evidence
     ↓
AI explanation
```

AI use cases:

- summarize weekly review;
- explain trends;
- convert natural language into tasks;
- help classify quick captures;
- answer questions about personal history.

AI must not be required for core functionality.

---

# 35. Deferred Features

Do not build these until the core system proves useful:

- social features;
- sharing;
- public profiles;
- leaderboards;
- full Notion replacement;
- full project management;
- bank integrations;
- phone-only sleep detection;
- complex geofencing;
- multi-user accounts;
- cloud database;
- mandatory AI;
- continuous location tracking.

---

# 36. Android OS Integrations

After core domains stabilize:

## Widgets

Useful widgets:

```text
Today
Quick Capture
Habit checklist
Focus timer
Next calendar event
```

Prefer actions that can be completed without opening the app.

## Notifications

Actionable notifications only.

## Focus / foreground controls

Provide persistent controls while a Focus session is active.

---

# 37. Sync — Future Architecture

Do not implement now.

Prepare contracts for:

```text
SyncableRecord
├── id
├── createdAt
├── updatedAt
├── deletedAt
└── revision/source metadata
```

Future sync engine:

```text
Local DB
  ↓
Change detector
  ↓
Sync queue
  ↓
Transport
  ↓
Remote store
```

Remote store could later be:

- custom API;
- PostgreSQL backend;
- Supabase;
- self-hosted service;
- another storage system.

The LifeOS domain layer must not care.

---

# 38. Conflict Strategy — Decide Before Sync

When sync is eventually implemented, define per-entity conflict behavior.

Default candidate:

```text
last-write-wins
```

But do not blindly apply it to everything.

Examples:

- Tasks: field-level or last-write-wins may be acceptable.
- Journal: append-oriented model is safer.
- Habit entries: set/identity-based merge.
- Expenses: immutable/append-oriented where possible.
- Health imports: source record identity + provenance.

This is a future design decision, not current implementation work.

---

# 39. Testing Strategy

Every new domain/integration must have:

### Unit tests

- model rules;
- derivations;
- repositories;
- migrations;
- import normalization.

### Widget tests

- loading;
- empty;
- error;
- populated;
- permission denied states.

### Integration tests

Critical flows:

```text
Create data
↓
Persist
↓
Restart
↓
Data survives
```

Health Connect should have adapter tests using fake/mock source data rather than requiring a real wearable for every test.

---

# 40. Health Connect Acceptance Tests

## Permissions

- user grants sleep permission;
- user denies sleep permission;
- user revokes permission later;
- LifeOS handles all states.

## Sleep import

- one sleep session imports;
- session crossing midnight imports correctly;
- sleep stages import correctly;
- missing stages do not fail import;
- duplicate record does not create duplicate local data;
- source metadata is retained.

## Incremental import

- first import creates records;
- second import does not duplicate records;
- updated external records are reconciled;
- failed import can retry.

## No Health Connect data

The Wellness domain remains usable.

Show:

```text
No health data available.
Connect Health Connect to import data.
```

Do not crash or fabricate values.

---

# 41. Data Ownership

LifeOS must distinguish:

### Native LifeOS data

Created directly by the user:

```text
Task
Habit
Goal
Journal
Expense
FocusSession
```

### Imported data

Created elsewhere:

```text
Health Connect
Calendar
future integrations
```

Imported data should preserve provenance.

Do not silently overwrite native records with external records.

---

# 42. Privacy

Because the application is intended to keep personal data local:

- no analytics SDK by default;
- no telemetry by default;
- no cloud account required;
- no health data uploaded;
- no background location unless explicitly added later;
- permissions requested only when needed;
- clear permission settings;
- export remains user-controlled.

Health data should never be sent to a remote service as part of normal LifeOS operation.

---

# 43. Recommended Delivery Order

## Milestone 1 — Stabilize

- [ ] Audit all existing domains
- [ ] Standardize IDs/timestamps
- [ ] Verify migrations
- [ ] Verify export includes every domain
- [ ] Add deletion/tombstone strategy where appropriate
- [ ] Improve repository boundaries
- [ ] Expand test coverage

## Milestone 2 — Daily Life

- [ ] Improve Tasks
- [ ] Improve Habits
- [ ] Connect Goals
- [ ] Quick Capture
- [ ] Journal improvements
- [ ] Focus improvements
- [ ] Planner improvements

## Milestone 3 — Review

- [ ] Daily Review
- [ ] Weekly Review
- [ ] Unified Timeline
- [ ] Better Home summary
- [ ] Actionable notifications

## Milestone 4 — Health Connect

- [ ] Android Health Connect adapter
- [ ] Permission management
- [ ] Sleep import
- [ ] Steps import
- [ ] Activity/workout import
- [ ] Heart rate import
- [ ] Resting heart rate
- [ ] Respiratory rate
- [ ] SpO₂
- [ ] Incremental import
- [ ] Provenance/deduplication
- [ ] Wellness summary

## Milestone 5 — Passive Context

- [ ] Calendar read integration
- [ ] Calendar → Planner availability
- [ ] Android widgets
- [ ] Focus notification controls

## Milestone 6 — Understanding

- [ ] Baselines
- [ ] Trends
- [ ] Cross-domain analytics
- [ ] Correlation views
- [ ] Evidence-based insights

## Milestone 7 — Intelligence

- [ ] AI-assisted classification
- [ ] AI weekly summaries
- [ ] Natural language task creation
- [ ] Personal history questions

## Milestone 8 — Sync

- [ ] Sync contracts
- [ ] Change tracking
- [ ] Tombstones
- [ ] Sync queue
- [ ] Conflict resolution
- [ ] Remote transport
- [ ] Server implementation

---

# 44. Definition of Done for a New Domain

A domain is not complete just because CRUD works.

It must have:

- [ ] domain model;
- [ ] local database schema;
- [ ] migration;
- [ ] repository;
- [ ] domain summary;
- [ ] standalone screen;
- [ ] Home contribution;
- [ ] empty state;
- [ ] error state;
- [ ] tests;
- [ ] export;
- [ ] deletion behavior;
- [ ] stable UUID;
- [ ] createdAt/updatedAt;
- [ ] future-sync consideration.

---

# 45. Definition of Done for an External Integration

Every external integration must have:

- [ ] adapter package/layer;
- [ ] permission model;
- [ ] normalized internal model;
- [ ] provenance;
- [ ] deduplication;
- [ ] incremental import;
- [ ] retry behavior;
- [ ] revoked-permission handling;
- [ ] local persistence;
- [ ] offline operation after import;
- [ ] tests without requiring the external service;
- [ ] clear settings UI.

---

# 46. Final Product Shape

The target LifeOS should eventually look like:

```text
                         LIFEOS
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
      MANAGE              CAPTURE             OBSERVE
        │                   │                   │
   Tasks / Habits       Quick Capture       Health Connect
   Goals / Focus        Journal / Notes     Calendar
   Finance              Rituals             Activity
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ↓
                         PLANNER
                            ↓
                          REVIEW
                            ↓
                        TIMELINE
                            ↓
                         BASELINES
                            ↓
                        ANALYTICS
                            ↓
                         INSIGHTS
                            ↓
                       AI (optional)
                            ↓
                       SYNC (later)
```

The important architectural boundary is:

```text
                ┌───────────────────────┐
                │       LifeOS UI       │
                └───────────┬───────────┘
                            │
                ┌───────────▼───────────┐
                │      Domain Layer     │
                └───────────┬───────────┘
                            │
                ┌───────────▼───────────┐
                │   Local Repository    │
                └───────────┬───────────┘
                            │
                     SQLite / Drift
                            │
              ┌─────────────┴─────────────┐
              │                           │
        External adapters            Future sync
              │                           │
       Health Connect                 Remote API
       Calendar                       Self-hosted
```

**The local database is the source of truth for the current application. External integrations are ingestion sources. Sync is a future transport concern.**

That separation should let LifeOS grow significantly without turning the current local-first architecture into a cloud-first application.
