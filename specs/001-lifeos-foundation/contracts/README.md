# LifeOS Contracts — Index

Interface contracts that make the foundation extensible. These are the
project's external-surface contracts: the application's own public package
interfaces (module registry and summary/export formats), following the
constitution's *explicit boundaries* principle (IV) and the *extensibility*
constraints.

| Contract | Purpose | Requirements |
|----------|---------|--------------|
| [domain-module-contract.md](domain-module-contract.md) | How a domain registers with the app and what it must implement | FR-005, FR-006, FR-012 |
| [domain-summary-contract.md](domain-summary-contract.md) | The summary each domain produces for the home overview | FR-001, FR-007 |
| [export-format-contract.md](export-format-contract.md) | The portable one-tap export envelope | FR-013, SC-009 |

## Versioning rules (all contracts)

- Contracts are **additive**: adding a field to a summary, a kind to
  `HighlightedItem.action`, or a key to the export envelope MUST NOT require
  an existing domain or consumer to change (FR-006).
- Breaking a contract (removing/renaming a field, changing semantics)
  REQUIRES a documented migration plan approved under the constitution's
  Governance section and a `schemaVersion` bump where the artifact is
  persisted (export).
- New domains MUST implement the current contract version; older versions
  remain readable for one release cycle.