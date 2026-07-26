# Architecture Decision Records

## ADR-001

Decision

Use Flutter

Reason

Cross Platform

Status

Accepted

---

## ADR-002

Decision

Use Riverpod

Reason

Scalable

Status

Accepted

---

## ADR-003

Decision

Use Hive

Reason

Offline First

Status

Accepted

---

## ADR-004

Decision

Use a versioned canonical ingredient registry and unit contract as the shared
identity boundary for Pantry, Recipe, Recommendation, and future Shopping.
Pantry lots retain separate lot IDs, while `canonicalIngredientId` identifies
what the lot contains.

Reason

Free-text names and duplicated unit logic made identity, conversion, migration,
and cross-feature joins ambiguous. Stable IDs allow offline deterministic
matching and preserve multiple expiry-dated lots of the same ingredient.

Consequences

- Registry definitions must have globally unique, normalized IDs.
- Recipe ingredient IDs must resolve in the registry.
- Legacy local data migrates before Riverpod state publication.
- Unknown or ambiguous values are preserved and reported, never guessed.
- Unit conversions must use `UnitConversionEngine`.
- Shopping may consume this domain model but is not implemented by this ADR.

Status

Accepted
