# Contract: DomainSummary — the home overview contract

**Requirements**: FR-001 (unified home from every enabled domain), FR-007
(consistent documented summary), FR-003 (fresh on return), SC-002, SC-007.

## Shape

```text
DomainSummary {
  domainKey:   string              // matches ModuleDescriptor.key
  displayName: string
  counts:      map<string, int>    // semantic counts (see below)
  highlighted: list<HighlightedItem>
  refreshedAt: datetime            // UTC, when the summary was computed
}

HighlightedItem {
  id:       string                 // stable reference (task/habit id)
  kind:     string                 // e.g. "task.due", "task.overdue", "habit.today"
  title:    string                 // short display text
  subtitle: string | null
  action:   enum { complete, openDomain }
}
```

## Semantics

- `counts` keys MUST be namespaced by domain and mean the same every render:
  tasks use `outstanding`, `overdue`, `completedToday`; habits use
  `doneToday`, `streaksActive`. New keys MAY be added; existing keys MUST
  NOT be repurposed.
- `highlighted` MAY be empty; items MUST be ordered by priority (overdue,
  then nearest due, then today's habits). The list is capped at a small,
  phone-friendly number (Home renders up to 3 per domain by default).
- `action = complete` is allowed only for kinds where the domain can safely
  complete the item by id without extra input (direct home action, SC-007).
  `action = openDomain` always falls back to the module's own screen.
- `refreshedAt` lets Home detect stale tabs; Home recomputes all summaries
  on return-to-home (FR-003) and never caches across navigation.

## Consumption rules (FR-012)

- Home depends on this contract shape; it has no knowledge of task/habit
  internals. Domains implement the contract; Home consumes it. Unknown
  `counts` keys or `kind` values MUST be ignored gracefully by Home (old
  Home, new domain and vice versa — additive evolution).

## Evolution

- Adding fields is additive and MUST NOT break existing consumers.
- Removing/renaming a top-level field is a breaking change requiring the
  contract versioning procedure in [README.md](README.md).