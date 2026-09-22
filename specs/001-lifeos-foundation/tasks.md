---

description: "Task list for LifeOS Foundation implementation"
---

# Tasks: LifeOS Foundation

**Input**: Design documents from `/specs/001-lifeos-foundation/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Test tasks are included because the project constitution (Principle IV,
Development Workflow) mandates automated test coverage for every module and
a passing test suite before a change is complete, and research.md D-8 defines
the per-package + integration testing strategy. Write each story's tests
first and confirm they fail before implementing.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Flutter monorepo (mobile-first)**: `app/` shell + `packages/` (core, storage, domains/tasks, domains/habits, export) per plan.md
- Paths below reflect the real monorepo layout from plan.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Initialize Flutter app shell in app/ (flutter create with android,ios targets; remove platform defaults not needed)
- [X] T002 [P] Create pure-Dart core package skeleton in packages/core/ (dart create -t package)
- [X] T003 [P] Create storage package skeleton in packages/storage/ (dart create -t package, flutter: none)
- [X] T004 [P] Create export package skeleton in packages/export/ (dart package, flutter: none)
- [X] T005 [P] Create tasks domain package skeleton in packages/domains/tasks/ (dart package)
- [X] T006 [P] Create habits domain package skeleton in packages/domains/habits/ (dart package)
- [ ] T007 Wire path dependencies per plan.md structure decision: app/pubspec.yaml depends on core, storage, domains/tasks, domains/habits, export; domains depend on core and storage only; no package depends on app/
- [X] T008 Configure analysis_options.yaml with Dart lints (flutter_lints) in every package and app/
- [ ] T009 Pin and document the Flutter/Dart stable SDK versions (research D-1) in README.md at repo root

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T010 Create ModuleDescriptor model in packages/core/lib/src/module.dart with fields per contracts/domain-module-contract.md: key (string, permanent), name, buildSummary(): DomainSummary, store handle
- [X] T011 [P] Create DomainSummary and HighlightedItem models in packages/core/lib/src/summary.dart with fields per contracts/domain-summary-contract.md (domainKey, displayName, counts Map<String,int>, highlighted List<HighlightedItem>, refreshedAt UTC; HighlightedItem {id, kind, title, subtitle?, action enum {complete, openDomain}})
- [X] T012 [P] Implement ModuleRegistry in packages/core/lib/src/registry.dart: register descriptors, enable/disable with persisted state, expose ONLY enabled modules to consumers (contracts/domain-module-contract.md lifecycle guarantees)
- [X] T013 [P] Implement UUID (v4) id generation helper in packages/core/lib/src/ids.dart per data-model.md conventions (collision-safe for future sync)
- [X] T014 Create AppDatabase in packages/storage/lib/src/database.dart (drift with schemaVersion 1, migration scaffold per data-model.md audit-field conventions; add drift deps and build.yaml; run build_runner)
- [X] T015 [P] Implement drift audit-field mixin (created_at/updated_at UTC, refreshed on every write) in packages/storage/lib/src/history.dart per data-model.md
- [X] T016 [P] Add in-memory drift database test utility in packages/storage/test/helpers.dart (NativeDatabase.memory() per research D-8)
- [ ] T017 Wire app bootstrap: open AppDatabase and build ModuleRegistry in app/lib/bootstrap/database.dart and app/lib/bootstrap/registry.dart
- [ ] T018 [P] Configure flutter_riverpod providers (databaseProvider, registryProvider) in app/lib/app.dart (research D-4, no codegen)
- [ ] T019 Run flutter test in packages/core, packages/storage, and app/ — foundation suites green (constitution Development Workflow gate)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Unified Home Overview (Priority: P1) 🎯 MVP

**Goal**: A mobile-first home screen that aggregates per-domain summaries (counts + highlighted actionable items), shows an empty state, and navigates to each enabled domain (FR-001..FR-004, FR-007, SC-002/006/007/008).

**Independent Test**: Launch the app with no domain data → home renders the empty state and navigation to the registered Tasks and Habits module screens; injecting fixture summaries renders summary cards and the highlighted section.

### Tests for User Story 1 (constitution-mandated — write first, confirm FAIL) ⚠️

- [ ] T020 [P] [US1] Widget test: home shows empty state when no domain has data (FR-004) in app/test/home_screen_test.dart
- [ ] T021 [P] [US1] Widget test: summary cards render from DomainSummary fixtures with counts and highlighted items (FR-001, FR-007) in app/test/home_screen_test.dart
- [ ] T022 [P] [US1] Widget test: HighlightedItem with action=complete dispatches direct completion without leaving home (SC-007) in app/test/home_screen_test.dart
- [ ] T023 [P] [US1] Widget test: home refreshes on return-to-home with no manual refresh (FR-003, SC-002) in app/test/home_screen_test.dart

### Implementation for User Story 1

- [ ] T024 [US1] Create HomeScreen shell with navigation to enabled domains (FR-002) in app/lib/home/home_screen.dart
- [ ] T025 [P] [US1] Create SummarySection widget rendering per-domain counts (up to 3 highlighted items per domain by default) in app/lib/home/summary_section.dart
- [ ] T026 [P] [US1] Create HighlightedSection widget rendering actionable HighlightedItems (complete / openDomain) in app/lib/home/highlighted_section.dart
- [ ] T027 [US1] Implement empty-state guidance UI (FR-004) in app/lib/home/home_screen.dart
- [ ] T028 [US1] Implement HomeController: fetches summaries from ModuleRegistry for enabled modules, refreshes on return to home (FR-001, FR-003) in app/lib/home/home_controller.dart
- [ ] T029 [US1] Register TasksModule and HabitsModule descriptors returning zero-count stub summaries in app/lib/bootstrap/registry.dart (data-backed summaries arrive in US2/US3)
- [ ] T030 [P] [US1] Create placeholder domain screens as navigation targets (replaced by full experiences in US2/US3) in app/lib/navigation/domain_placeholder_screen.dart
- [ ] T031 [US1] Integration test: launch → empty state → navigate to Tasks and Habits placeholders and back (US1 Independent Test) in app/integration_test/home_flow_test.dart

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Tasks as the First Domain (Priority: P1)

**Goal**: A dedicated Tasks module with the complete basics-only lifecycle — create, edit, complete, delete, order, optional due date — feeding its summary to home (FR-010, SC-001).

**Independent Test**: Use the Tasks module end-to-end (create → edit → complete → delete) without touching home or Habits; then verify the task summary appears on home.

### Tests for User Story 2 (constitution-mandated — write first, confirm FAIL) ⚠️

- [ ] T032 [P] [US2] Unit tests: Task model and status transitions in packages/domains/tasks/test/task_test.dart — overdue derived as `status = outstanding` and `dueDate < today`; toggle complete/undo is idempotent with no duplicates; title required 1-200 chars after trim; position non-negative (data-model.md verbatim)
- [ ] T033 [P] [US2] Repository tests against in-memory drift in packages/domains/tasks/test/task_repository_test.dart — create, edit, complete, delete, ordering, audit fields refreshed
- [ ] T034 [P] [US2] Summary tests in packages/domains/tasks/test/task_summary_test.dart — counts keys outstanding/overdue/completedToday and highlight priority (overdue first, then nearest due)

### Implementation for User Story 2

- [ ] T035 [P] [US2] Create immutable Task model in packages/domains/tasks/lib/src/task.dart (id UUID, title, dueDate Date?, status enum {outstanding, completed}, position int, createdAt/updatedAt UTC)
- [ ] T036 [P] [US2] Define TaskTable drift schema in packages/domains/tasks/lib/src/task_table.dart matching data-model.md Task entity
- [ ] T037 [US2] Implement TaskRepository (create/edit/complete/delete/order; derives overdue; toggles idempotently) in packages/domains/tasks/lib/src/task_repository.dart (depends on T035, T036)
- [ ] T038 [P] [US2] Implement TaskSummary builder (outstanding, overdue, completedToday; overdue-first highlighting) in packages/domains/tasks/lib/src/task_summary.dart per contracts/domain-summary-contract.md
- [ ] T039 [US2] Implement TasksModule descriptor with repository-backed buildSummary (replaces US1 stub) in packages/domains/tasks/lib/tasks_module.dart
- [ ] T040 [US2] Build Tasks screen UI (list; create/edit/complete/delete; manual ordering; undated section separate from overdue) in app/lib/navigation/task_screen.dart
- [ ] T041 [US2] Wire Tasks screen to TaskRepository and TasksModule via riverpod providers in app/lib/navigation/task_screen.dart
- [ ] T042 [P] [US2] Integration test: full task lifecycle and summary appearing on home (US2 Independent Test; SC-001 timing and SC-002 freshness) in app/integration_test/tasks_flow_test.dart

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Habits as a Second Domain (Priority: P2)

**Goal**: A dedicated Habits module with preset schedules (daily / weekly / days-of-week), per-day completion, history and streaks — coexisting with Tasks without interference (FR-011).

**Independent Test**: Define a daily and a weekly habit, record completions on scheduled days, and verify streaks/history — all inside the Habits module without using Tasks or home.

### Tests for User Story 3 (constitution-mandated — write first, confirm FAIL) ⚠️

- [ ] T043 [P] [US3] Unit tests: Habit + preset Schedule validation in packages/domains/habits/test/habit_test.dart — name required 1-100 chars; weekly schedule must include at least one weekday (data-model.md verbatim); daily carries no day set
- [ ] T044 [P] [US3] Unit tests: streak & history computation in packages/domains/habits/test/streak_test.dart — daily counts consecutive days; weekly counts only scheduled days; unscheduled days never count as missed (data-model.md derivation rules verbatim)
- [ ] T045 [P] [US3] Repository tests in packages/domains/habits/test/habit_repository_test.dart — one entry per (habitId, date) enforced; record/un-record idempotent
- [ ] T046 [P] [US3] Summary tests in packages/domains/habits/test/habit_summary_test.dart — doneToday and streaksActive counts, today's habits highlighted

### Implementation for User Story 3

- [ ] T047 [P] [US3] Create immutable Habit model and Schedule type in packages/domains/habits/lib/src/habit.dart (schedule {daily} or {weekly, daysOfWeek Set<1..7>})
- [ ] T048 [P] [US3] Define HabitTable and HabitEntryTable drift schemas in packages/domains/habits/lib/src/habit_table.dart with composite unique (habitId, date)
- [ ] T049 [US3] Implement HabitRepository (define habit; record/un-record entries; list history) in packages/domains/habits/lib/src/habit_repository.dart (depends on T047, T048)
- [ ] T050 [P] [US3] Implement streak logic in packages/domains/habits/lib/src/streak.dart per data-model.md (daily: consecutive present entries ending today/yesterday; weekly: consecutive scheduled weeks)
- [ ] T051 [P] [US3] Implement HabitSummary builder (doneToday, streaksActive; highlight today's schedules) in packages/domains/habits/lib/src/habit_summary.dart
- [ ] T052 [US3] Implement HabitsModule descriptor with repository-backed buildSummary (replaces US1 stub) in packages/domains/habits/lib/habits_module.dart
- [ ] T053 [US3] Build Habits screen UI (define habit with preset schedule; record/un-record; history + streak view) in app/lib/navigation/habit_screen.dart
- [ ] T054 [US3] Wire Habits screen to HabitRepository and HabitsModule via riverpod providers in app/lib/navigation/habit_screen.dart
- [ ] T055 [P] [US3] Integration test: habits coexist with tasks (no cross-domain effect), streaks render, habit summary on home (US3 Independent Test) in app/integration_test/habits_flow_test.dart

**Checkpoint**: All user stories so far independently functional

---

## Phase 6: User Story 4 - Local-First Operation (Priority: P2)

**Goal**: Guarantee the app is fully functional offline with data persisting on the device across restarts, and that no sync code paths exist (FR-008, FR-009, SC-004, SC-005).

**Independent Test**: Enable airplane mode, use home/Tasks/Habits, fully quit the app, reopen — everything works and data is intact.

### Tests for User Story 4 (constitution-mandated — write first, confirm FAIL) ⚠️

- [ ] T056 [P] [US4] Integration test: all core functions (home, Tasks, Habits) operate with network disabled (SC-004) in app/integration_test/offline_test.dart
- [ ] T057 [P] [US4] Integration test: data created offline survives a full app restart with zero loss (FR-009, SC-005) in app/integration_test/persistence_test.dart

### Implementation for User Story 4

- [ ] T058 [US4] Audit app/ and packages/ for network permissions and network calls (FR-008); remove any and add a test assertion that no connectivity APIs are referenced (android/iOS manifests; pubspec deps)
- [ ] T059 [P] [US4] Performance baseline test: seed 1,000 tasks + 500 habit entries; home renders in under 1 second (SC-006) in app/integration_test/performance_test.dart
- [ ] T060 [US4] Confirm there is no sync UI, no connectivity prompts, and no failed network calls in any flow (FR-008 + edge case "no sync before sync exists") in app/lib/bootstrap/, app/lib/home/, app/lib/navigation/, and packages/*/pubspec.yaml

**Checkpoint**: Local-first guarantees verified

---

## Phase 7: User Story 5 - Adding a New Domain (Priority: P3)

**Goal**: First-class enable/disable of domain modules without disturbing other domains or their data; a registered new domain appears on home automatically (FR-005, FR-006, SC-003).

**Independent Test**: Disable a domain (gone from home), re-enable it (data returns), and register a throwaway third module — no existing domain package changes.

### Tests for User Story 5 (constitution-mandated — write first, confirm FAIL) ⚠️

- [ ] T061 [P] [US5] Integration test: disable module → absent from home, data retained; re-enable → data returns exactly (FR-005) in app/integration_test/domain_lifecycle_test.dart
- [ ] T062 [P] [US5] Integration test: registering a third throwaway module requires zero changes to existing domain packages and its summary appears on home (FR-006, FR-007, SC-003) in app/integration_test/extensibility_test.dart

### Implementation for User Story 5

- [ ] T063 [US5] Implement module enable/disable control UI (settings entry listing installed domains) in app/lib/bootstrap/registry_settings.dart
- [ ] T064 [US5] ModuleRegistry: persist enabled state across restarts and expose only enabled modules to home in packages/core/lib/src/registry.dart (contracts/domain-module-contract.md lifecycle guarantees)
- [ ] T065 [P] [US5] HomeController: automatically present summaries of newly enabled domains with the existing ordering (FR-003, FR-007) in app/lib/home/home_controller.dart
- [ ] T066 [US5] Update contracts/domain-module-contract.md with any refinements learned during implementation (extensibility verification, SC-003)

**Checkpoint**: Extensibility story proven

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T067 Implement ExportEnvelope writer (schemaVersion 1, exportedAt, appVersion, per-domain payloads incl. disabled-domain data) in packages/export/lib/src/exporter.dart per contracts/export-format-contract.md (FR-013)
- [ ] T068 [P] Implement one-tap share-sheet delivery (share_plus + path_provider) in packages/export/lib/src/share.dart (FR-013)
- [ ] T069 Export completeness test — envelope contains every owned record including disabled-domain data (SC-009) in packages/export/test/exporter_test.dart
- [ ] T070 [P] Export failure test — storage-full style failure leaves data unmodified, clear user message, retry succeeds (edge case) in packages/export/test/exporter_failure_test.dart
- [ ] T071 [P] Documentation: record implementation outcomes and any post-plan deviations as ADRs (constitution Principle V) in specs/001-lifeos-foundation/research.md and plan.md
- [ ] T072 [P] Run flutter analyze across all packages and app/ — zero warnings, lints clean
- [ ] T073 [P] Execute every scenario in specs/001-lifeos-foundation/quickstart.md end-to-end and fix any gaps found
- [ ] T074 Write repo-root README.md with setup, run, and test instructions (flutter pub get, build_runner, flutter test, flutter run)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - US1 (home shell) is first (P1, MVP); US2 (tasks) follows immediately (also P1)
  - US1 stubs (T029/T030) are replaced by real module implementations in US2 (T039/T040) and US3 (T052/T053)
  - US3, US4, US5 can proceed in parallel after US1/US2 (if staffed), or sequentially in priority order
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational — no dependencies on other stories (stub summaries)
- **User Story 2 (P1)**: Can start after Foundational — replaces US1's Tasks stub; independently testable
- **User Story 3 (P2)**: Can start after Foundational — replaces US1's Habits stub; independently testable
- **User Story 4 (P2)**: Can start after US1+US2 (verifies their offline/persistence behavior); Habits optional
- **User Story 5 (P3)**: Can start after US1; best after US2/US3 (proof uses real domains + their data)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services; services before screens; screens before integration
- Core implementation before integration; story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002–T006; T007 depends on them; T008/T009 independent)
- All Foundational tasks marked [P] can run in parallel (T011–T018; T010 and T014 are the structural anchors)
- Once Foundational completes, US1..US5 can start in parallel (if capacity allows each story its own lane)
- Tests within a story marked [P] run in parallel (e.g., T032/T033/T034 for US2)
- Models within a story marked [P] run in parallel (e.g., T035/T036 for US2)

---

## Parallel Example: User Story 2

```bash
# Launch all tests for User Story 2 together (write first, expect FAIL):
Task: "Unit tests: Task model and status transitions in packages/domains/tasks/test/task_test.dart"
Task: "Repository tests against in-memory drift in packages/domains/tasks/test/task_repository_test.dart"
Task: "Summary tests in packages/domains/tasks/test/task_summary_test.dart"

# Launch all models for User Story 2 together:
Task: "Create immutable Task model in packages/domains/tasks/lib/src/task.dart"
Task: "Define TaskTable drift schema in packages/domains/tasks/lib/src/task_table.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (home shell with empty state + navigation to stub modules)
4. **STOP and VALIDATE**: Test User Story 1 independently (T031)
5. Deploy/demo the shell if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Demo (shell MVP)
3. Add User Story 2 (Tasks) → Test independently → Demo — this is the first *value-complete* demo (both P1 stories per spec)
4. Add User Story 3 (Habits) → Test independently → Demo
5. Add User Story 4 (local-first verification) and User Story 5 (extensibility) → Test independently
6. Polish: export + docs + quickstart validation
7. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (home shell)
   - Developer B: User Story 2 (Tasks)
   - Developer C: User Story 3 (Habits)
3. US4/US5 follow as verification passes; stories complete and integrate independently
4. T029/T030 (US1 stubs) are owned by Developer A; US2/US3 replace only their own stubs

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Domain packages stay pure-Dart (no Flutter imports) except screens, which live in app/ per plan.md