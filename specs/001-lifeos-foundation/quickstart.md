# Quickstart: LifeOS Foundation

Validation guide that proves the feature works end-to-end. Implementation
details live in `tasks.md` (Phase 2); this file is the run guide.

## Prerequisites

- Flutter SDK (stable channel) installed and on `PATH`: `flutter --version`
- A device or emulator (Android or iOS) available: `flutter devices`
- Dart enabled for package tests (bundled with Flutter)

## Setup

```sh
# 1. Fetch dependencies for every package (path dependencies resolve across
#    the monorepo from app/).
cd app && flutter pub get

# 2. Generate drift table code.
dart run build_runner build --delete-conflicting-outputs

# 3. (Optional) regenerate once after pulling, not per-test.
```

## Run the tests

```sh
# Per-package unit + widget tests (each domain runs independently; the app
# shell is not required): runs from each package directory.
flutter test                                   # packages/core, storage, tasks, habits, export
flutter test                                   # app/ (widget tests for Home)

# End-to-end user journeys (user stories 1-5, offline + persistence checks).
flutter test integration_test                  # app/
```

Expected: all suites pass with no network access required.

## Launch the app

```sh
cd app && flutter run        # pick a connected mobile device/emulator
```

First launch shows the Home overview in its empty state (FR-004) with
navigation to the available domains (FR-002).

## Validation scenarios (manual, mapped to acceptance criteria)

### Home overview (User Story 1, FR-001..FR-004, SC-002/006/007/008)

1. First launch → welcoming empty state, no blank/error screen.
2. Create a task, open Home → task summary (outstanding count) appears with
   no manual refresh (SC-002).
3. From Home, open a domain, then navigate back → summary is current.
4. With items needing attention → highlighted section shows next due /
   overdue / today's habits; tapping an item that supports direct action
   completes it from Home within 5 seconds (SC-007).

### Tasks (User Story 2, FR-010, SC-001)

1. Create → edit → complete → delete a task; verify list updates immediately.
2. Due date in the past with status = outstanding → shown as overdue.
3. Creating a task without a due date → undated area; never overdue.
4. Mark complete twice / undo → no duplicates (idempotent).

### Habits (User Story 3, FR-011)

1. Define a daily habit and a weekly habit (e.g., Mon/Wed/Fri).
2. Record completion on scheduled days → streak and history update;
   unscheduled days are never counted as missed.
3. Add items in Tasks and Habits interleaved → neither domain affects the
   other.

### Local-first & persistence (User Story 4, FR-008/009, SC-004/005)

1. Enable airplane mode, relaunch the app → all core functions work fully
   offline (SC-004).
2. Create data, fully quit (swipe away), reopen → data intact (SC-005).
3. No sync UI, no failed network calls, no connectivity prompts.

### Adding a domain (User Story 5, FR-005/006, SC-003)

1. Disable a module → gone from Home; its data retained.
2. Re-enable it → data returns exactly as before.
3. Register a new (throwaway) domain package implementing the module
   contract → it appears on Home without touching any existing domain
   package (SC-003).

### Export (FR-013, SC-009)

1. One tap → share sheet with a portable JSON file; open it and confirm
   every task/habit/entry is present (SC-009).
2. Disable a domain, export again → its data is still in the file.
3. Force a failure (e.g., full storage) → clear message, no data modified,
   retry succeeds.

## Reference

- Data model & derivation rules: [data-model.md](data-model.md)
- Interface contracts: [contracts/](contracts/README.md)
- Decisions & rationale: [research.md](research.md)
- Feature spec & success criteria: [spec.md](spec.md)