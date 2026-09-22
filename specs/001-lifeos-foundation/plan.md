# Implementation Plan: LifeOS Foundation

**Branch**: `001-lifeos-foundation` | **Date**: 2026-09-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-lifeos-foundation/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

Build the LifeOS foundation: a mobile-first personal operating system shell
with a unified home overview, a modular domain mechanism, and two pilot
domains (Tasks and Habits) running fully local-first, plus a one-tap
portable export.

Technical approach (resolved in [research.md](research.md)): a Flutter
(Dart) monorepo of packages — a pure-Dart `core` package holding the domain
registry and summary contracts, `storage` for local SQLite persistence,
one package per domain (`tasks`, `habits`) exposing typed logic and
summaries, an `export` package for portable JSON export, and a Flutter
`app` shell that composes the home overview as a consumer of domain
summaries — not as a hub they depend on. No network dependency in v1.

## Technical Context

**Language/Version**: Dart 3 / Flutter (stable channel); exact SDK version pinned in research.md

**Primary Dependencies**: Flutter SDK; `drift` + `sqlite3_flutter_libs` (local
SQLite with typed tables and codegen); `flutter_riverpod` (state management,
no codegen); `build_runner` (drift codegen); `share_plus` + `path_provider`
(one-tap export delivery); `flutter_test` / `integration_test` (testing)

**Storage**: Local SQLite via drift (offline-first, survives restarts). No cloud,
no network storage in v1. Export produced as a portable JSON file.

**Testing**: `flutter_test` (unit + widget tests per package), `integration_test`
(end-to-end through the app shell), drift in-memory database for repository
tests. CI runs per-package suites and the app integration suite.

**Target Platform**: Android + iOS (mobile-first per clarification Q1)

**Project Type**: Mobile application (Flutter), delivered as a modular monorepo
of Dart packages

**Performance Goals**: Home renders < 1s with 1,000 tasks + 500 habit entries
(SC-006); smooth 60fps interactions; no manual refresh on home (SC-002)

**Constraints**: Fully offline-capable (FR-008); data persists across restarts
(FR-009); single-user local-first; dependency flow is consumers → domains,
never the reverse (FR-012); export must be one-tap and portable (FR-013)

**Scale/Scope**: Single user; baseline data volume ~1,000 tasks and 500 habit
entries per year (SC-006); two pilot domains + home overview + export;
architecture must leave the door open for future domains, sync, and AI

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**I. Modular Domain Autonomy** — PASS: one package per domain; domains depend
only on `core`/`storage`, never on the app shell or home; the registry and
summary contracts live in `core` so home is one consumer among equals.

**II. Simplicity Over Premature Complexity** — PASS: no backend, no network,
tasks limited to basics-only per clarification Q3; dependencies are the
smallest set that satisfies the spec; no speculative abstractions for
domains not yet built.

**III. Local-First, Designed for the Future** — PASS: all persistence is local
SQLite; no network calls exist; tables carry UUID ids and `updated_at`
timestamps and the export envelope is schema-versioned, so a future sync
effort stays additive (Principle III + Assumptions).

**IV. Explicit Boundaries, Strong Typing, and Automated Tests** — PASS: typed
contracts in `core` (module descriptor, domain summary), drift-typed tables,
immutable domain models, per-package unit/widget tests plus an
integration suite; codebase stays readable and machine-verifiable for
future AI agents.

**V. Documented Decisions and Incremental Delivery** — PASS: every technology
decision recorded as Decision/Rationale/Alternatives in research.md;
delivery proceeds in the small increments defined by tasks.md, each
leaving the app runnable and tested.

**Extensibility & Integration Constraints** — PASS: contracts are additive and
schema-versioned; new domains are new packages registered through the
module descriptor; no domain package depends on the dashboard.

**Development Workflow** — PASS: test suites gate every package; changes land
in small self-contained increments with decision records updated.

Gate result: **PASS — no violations**. Re-checked after Phase 1 design below
and still satisfied (see "Constitution check post-design" note in
[research.md](research.md)).

## Project Structure

### Documentation (this feature)

```text
specs/001-lifeos-foundation/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

Modular Flutter monorepo using Dart path dependencies (no third-party
workspace tooling in v1):

```text
app/                                # Flutter application shell (mobile-first)
├── lib/
│   ├── main.dart                   # entrypoint: bootstrap DB + registry, run app
│   ├── app.dart                    # root widget, theme, navigation
│   ├── bootstrap/
│   │   ├── registry.dart           # builds ModuleRegistry from installed packages
│   │   └── database.dart           # opens the shared drift database
│   ├── home/
│   │   ├── home_screen.dart        # home overview (FR-001..FR-004, SC-002/006/007/008)
│   │   ├── summary_section.dart    # per-domain summary cards + empty state
│   │   └── highlighted_section.dart# actionable highlighted items (FR-001, SC-007)
│   └── navigation/                 # home ⇄ domain navigation (FR-002)
└── test/
    ├── home_screen_test.dart       # widget tests: summary render, empty state, refresh
    └── app_integration_test.dart   # integration_test flow for user stories 1-5

packages/
├── core/                           # pure Dart: shared foundation, no Flutter UI
│   ├── lib/src/module.dart         # ModuleDescriptor + ModuleRegistry (FR-005/006/012)
│   ├── lib/src/summary.dart        # DomainSummary & HighlightedItem contract (FR-001/007)
│   ├── lib/src/ids.dart            # UUID id generation rules
│   └── test/
├── storage/                        # drift database: connection, schema, migrations
│   ├── lib/src/database.dart       # shared AppDatabase (typed tables via codegen)
│   ├── lib/src/history.dart        # updated_at / audit fields helper
│   └── test/                       # in-memory DB tests
├── domains/
│   ├── tasks/                      # Tasks domain module (FR-010)
│   │   ├── lib/
│   │   │   ├── src/task.dart       # immutable Task model + status rules
│   │   │   ├── src/task_table.dart # drift table defs
│   │   │   ├── src/task_repository.dart
│   │   │   ├── src/task_summary.dart# builds DomainSummary for home
│   │   │   └── tasks_module.dart   # ModuleDescriptor implementation
│   │   └── test/                   # unit tests: lifecycle, ordering, overdue, summary
│   └── habits/                     # Habits domain module (FR-011)
│       ├── lib/
│       │   ├── src/habit.dart      # immutable Habit model + preset schedule
│       │   ├── src/habit_entry.dart
│       │   ├── src/schedule.dart   # daily / weekly / days-of-week logic
│       │   ├── src/streak.dart     # streak & history computation (edge cases)
│       │   ├── src/habit_repository.dart
│       │   ├── src/habit_summary.dart
│       │   └── habits_module.dart  # ModuleDescriptor implementation
│       └── test/                   # unit tests: schedule, streak, entries
└── export/                         # one-tap portable export (FR-013)
    ├── lib/src/exporter.dart       # JSON envelope, schema versioning
    ├── lib/src/share.dart          # share sheet integration (share_plus)
    └── test/                       # export completeness + failure handling
```

**Structure Decision**: The monorepo-of-packages layout was selected because it
is the only structure that satisfies *Modular Domain Autonomy* (Principle I)
and *Explicit Boundaries* (Principle IV) at the compile level: package
boundaries make it impossible for a domain to accidentally touch another
domain's internals, and the `app` shell can only consume domains through the
`core` contracts. Domains remain independently testable (their tests run
without the app). The `app/home` directory is intentionally a consumer, not
a hub: it contains no domain logic, only rendering of `DomainSummary`
instances received through the registry.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

None — the Constitution Check passes with no violations that require
justification. The only cross-cutting decisions (drift codegen, riverpod)
are justified in research.md as the minimal configuration consistent with
the simplicity principle (non-codegen state management; codegen confined to
the persistence layer that already needs typed table generation).