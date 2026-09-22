# LifeOS Constitution

## Core Principles

### I. Modular Domain Autonomy

Each domain — tasks, habits, finance, nutrition, fitness, journal, and time
tracking — MUST live in an independent module with explicit, documented
boundaries. Modules MUST NOT depend on another domain's internal state or
implementation details. The dashboard MUST NOT be the hub around which the
application is coupled; it MUST be one consumer of domain modules, equal to
any other interface or future integration.

Rationale: independence keeps each domain buildable, testable, extendable,
and replaceable without global rewrites, and keeps future consumers (CLI,
web, AI agents) first-class rather than afterthoughts of the UI.

### II. Simplicity Over Premature Complexity

The architecture MUST favor simplicity. Every module, abstraction,
dependency, and layer MUST justify its existence; unused structure MUST be
removed. Requirements not yet present MUST NOT be designed for in advance
(YAGNI) unless a concrete, documented need exists. Where complexity is
necessary, it MUST be accompanied by a written justification in the relevant
spec or decision record.

Rationale: simple systems are cheaper to maintain, easier to verify, and
safer for both humans and future AI agents to modify.

### III. Local-First, Designed for the Future

The system MUST remain local-first wherever practical: all core features
MUST work without network access or external services. Data models and
module contracts MUST be designed so that future synchronization,
third-party integrations, and AI capabilities can be added as extensions
without rewriting core modules.

Rationale: local-first guarantees availability and data ownership today,
while explicit, stable contracts keep synchronization, integration, and AI
open as evolutionary paths rather than rewrites.

### IV. Explicit Boundaries, Strong Typing, and Automated Tests

Modules MUST expose stable, versioned contracts (typed interfaces and shared
schemas) as their public surface. Strong typing MUST be used where it
improves safety and clarity. Automated tests MUST cover each module's
behavior in isolation and through its public contract. The codebase MUST
remain structured and readable so that future AI agents can safely
understand, modify, test, and extend it.

Rationale: explicit boundaries and tests make correctness verifiable by
machines as well as humans — a precondition for safe AI-driven extension.

### V. Documented Decisions and Incremental Delivery

Important architecture decisions MUST be documented — purpose, context, and
trade-offs — at the time they are made. Changes MUST be delivered
incrementally in small, reviewable steps, and each step MUST leave the
system in a working state with its tests passing. Large-bang rewrites and
unplanned refactors MUST NOT be merged.

Rationale: documented decisions preserve the rationale that later
maintainers and agents need; incremental delivery keeps risk low and the
history auditable.

## Extensibility & Integration Constraints

- Shared schemas and module contracts MUST be versioned and additive;
  breaking a contract REQUIRES a documented migration plan approved under
  Governance.
- New capabilities (synchronization, integrations, AI) MUST be implemented
  as extensions of domain modules and MUST NOT require rewriting the core.
- Domain modules MUST NOT depend on the dashboard; dependencies flow from
  consumers (including the dashboard) toward the domains.
- Data that may later need synchronization MUST be stored in a form that
  supports conflict-aware merging, or the deviation MUST be documented.

## Development Workflow

- The automated test suite MUST pass before any module or change is
  considered complete.
- Every unit of work MUST include or update the tests and the decision
  documentation it touches.
- Changes MUST be submitted in small, self-contained increments with clear
  descriptions and MUST NOT be merged in large-bang form.
- Architecture decisions MUST be recorded as they are made (decision record
  or equivalent under `docs/`).
- New dependencies and frameworks MUST be justified against Principle II and
  recorded in the relevant decision record.

## Governance

This constitution supersedes ad-hoc practices whenever a conflict arises
between them.

**Amendment procedure**:
1. Propose the change as a documented amendment stating the affected
   principle(s), rationale, and migration impact.
2. Apply semantic versioning per the policy below.
3. Obtain explicit approval before merging the amendment.
4. Update this document, including the Last Amended date.

**Versioning policy**:
- MAJOR: backward-incompatible removal or redefinition of a principle or
  governance rule.
- MINOR: a new principle or section, or materially expanded guidance.
- PATCH: clarifications, wording, typo fixes, and non-semantic refinements.

**Compliance review**:
- Pull requests and reviews MUST verify compliance with these principles
  before merge.
- Introduced complexity MUST be justified against Principle II.
- This constitution MUST be re-reviewed whenever the system's scope changes
  (for example, new domains, synchronization, or AI capabilities).

**Version**: 1.0.0 | **Ratified**: 2026-09-22 | **Last Amended**: 2026-09-22