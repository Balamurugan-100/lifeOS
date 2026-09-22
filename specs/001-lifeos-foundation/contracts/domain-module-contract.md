# Contract: DomainModule — registration and lifecycle

**Requirements**: FR-005 (enable/disable), FR-006 (new domains need no
changes to existing ones), FR-012 (domains never depend on the dashboard).

## Shape

Every domain package exposes a single `ModuleDescriptor`:

```text
ModuleDescriptor {
  key:        string            // stable id: "tasks", "habits", ...
  name:       string            // display name
  buildSummary(): DomainSummary // see domain-summary-contract.md
  store:      Storage            // capability handle provided by the app shell
}
```

The app shell owns a `ModuleRegistry` (in `core`) that:

1. Collects descriptors from all installed domain packages at startup.
2. Persists and restores each module's `enabled` state.
3. Exposes only *enabled* modules to the home overview.
4. Is the only place that knows all domains — individual domains know
   nothing about one another.

## Registration rule (FR-006)

Adding a domain = adding one package that implements `ModuleDescriptor` and
declaring it in one registry list. No other package changes; the home
overview renders whatever summaries the registry hands it (FR-003, FR-007).

## Lifecycle guarantees (FR-005)

- `disable`: module stops contributing to home and its module UI is
  unreachable; its data is retained and untouched.
- `re-enable`: module and its previous data return exactly as they were.
- Enabling/disabling one module MUST NOT read or modify any other module's
  data.

## Independence rule (FR-012)

- A domain package MAY depend on `core` and `storage` only.
- A domain package MUST NOT depend on the app shell, the home package, or
  another domain.
- Home MUST render only what arrives through `buildSummary()`; it holds no
  domain internals.

## Evolution

- New fields MAY be added to `ModuleDescriptor` (defaults required).
- `key` values are permanent once published — never renamed (stable
  identities matter for persistence and future sync).