# Changelog

## Unreleased

### Added

- `RecipeReadinessService` as the deterministic domain owner for Pantry-aware,
  quantity-aware Recipe evaluation.
- Weighted readiness scoring with hero/main, required supporting, optional, and
  garnish defaults plus explicit per-ingredient overrides.
- Typed Recipe readiness results containing available, missing, optional,
  shortage, canonical identity, unit compatibility, and quantity coverage data.
- Riverpod projections that recalculate readiness from Recipe + Pantry and
  guarantee one readiness result for every loaded Recipe.
- Recipe Detail readiness panel with percentage, progress, available/missing/
  optional groups, and shortage quantities.
- One-click `Add Missing Ingredients to Shopping` application action that reuses
  `ShoppingEngine.generate` and one durable Shopping upsert.
- Regression coverage for weighted scoring, partial quantities, mixed-unit
  aggregation, expiry, every-Recipe projection, Recipe Detail, batch Shopping,
  repeated-action deduplication, and fully ready no-op behavior.
- Actionable-only Shopping completion workflow: `เก็บเข้าตู้` atomically merges
  Pantry, records Purchase History, and removes the Shopping item.
- `PantryCanonicalMergeService` as the shared domain owner for canonical
  resolution, compatible-unit conversion, deterministic consolidation, and
  typed incompatible-unit failure.
- Durable `PurchaseHistoryEntry` read model projected from committed inventory
  transaction snapshots, including timestamp, resolved ingredient, quantity,
  Recipe sources, Shopping identity, Pantry transaction ID, and affected Pantry
  records.
- Conflict-safe Shopping completion Undo that restores only the Pantry records
  touched by the original purchase, restores the active Shopping item, and
  removes its projected Purchase History entry.
- Canonical Pantry merge coverage for Shopping completion and manual Pantry
  add/update, including localized alias fallback, mixed-unit conversion,
  duplicate consolidation, incompatible-unit failure, restart durability, and
  full Undo.
- Celebration state when an existing Shopping list has no unfinished items:
  `🎉 ไม่มีรายการที่ต้องซื้อแล้ว` and `พร้อมทำอาหารได้เลย`.
- Transaction-safe single-entry deletion and clear-all retention controls for
  Cooking History, both protected by confirmation dialogs.
- Shared `UnitPresentation` localization coverage for Pantry, Recipe, Shopping,
  cooking, and Cooking History.
- Canonical artwork metadata and backward-compatible presentation fallback.
- Ingredient-aware Unit Policy with preferred units, recommended units, and
  optional unit families on every canonical ingredient.
- SF-003 Shopping screen, multi-Recipe generation preview, canonical search,
  category/Recipe filters, deterministic sorting, Pantry availability, and
  durable edit/delete Undo.
- SF-002 `ShoppingEngine` for deterministic multi-Recipe aggregation, Pantry
  subtraction, canonical alias resolution, unit conversion, and active-demand
  merging.
- SF-001 Shopping entities and a read-only repository backed by the durable
  inventory envelope.
- Canonical Ingredient Registry, deterministic Unit Contract, startup migration,
  RFC-0003 inventory coordinator, checksummed envelope, and durable transaction
  journal.

### Changed

- Pantry is now the source for Recipe readiness decisions; readiness is derived
  instead of persisted so inventory changes cannot leave stale scores.
- Recipe ingredient data remains backward compatible while optionally accepting
  semantic importance and explicit readiness weight metadata.
- Missing-ingredient Shopping uses the existing canonical Shopping Engine rather
  than duplicating canonical resolution, Pantry subtraction, unit conversion, or
  deduplication rules in Recipe presentation.
- Recipe application code depends on a Shopping mutation executor contract;
  Riverpod and concrete controller wiring remain at the presentation boundary.
- Shopping now represents unfinished work only. The current UI no longer renders
  a Completed section/tab or archive/restore controls.
- Completing an item removes it immediately instead of changing it to
  purchased/archived state in the actionable list.
- Purchase History replaces Completed Shopping as the product history model and
  is derived from durable journal snapshots rather than another Hive box.
- Shopping regeneration carries forward active intent only; legacy completed or
  archived records cannot reappear after generation.
- Shopping read projections hide legacy non-active records while retaining their
  persisted data and embedded receipts for backward compatibility.
- Pantry add/update and Shopping completion use the same canonical merge rules.
  Compatible canonical duplicates are consolidated into one inventory record;
  incompatible units fail without mutation.
- Canonical merge priority is canonical ID redirect resolution, stable registry
  key, then localized/alias registry resolution. Display-name equality is not a
  merge rule.
- Shopping presentation publishes no optimistic durable state. Pantry, Shopping,
  and Purchase History refresh only after commit verification.
- Shopping-to-Pantry commits retain resolved canonical identity, artwork, and
  canonical unit IDs while using localized display units.
- Existing legacy Shopping lifecycle mutations remain readable and callable for
  compatibility tests/data, but the current UI does not invoke them.
- Canonical unknown-ID hashing uses web-compatible `BigInt` arithmetic while
  preserving the existing 64-bit FNV output.
- Pantry, Recipe, Recommendation, deduction, Cooking History, and Shopping paths
  carry canonical ingredient and unit identities.
- Startup recovery completes before application providers are initialized.

### Quality Status

- PR #6 and stacked PR #7 remain Draft.
- Recipe-readiness targeted tests, the full suite, analysis, formatting, diff,
  and manual web results must be recorded from the local Flutter environment
  before Ready for review.
- No pass result is claimed in this changelog until those commands complete.

## v0.1.0

### Added

- Flutter Setup
- Navigation
- Pantry
- Hive
- Riverpod

---

### Changed

- Initial Project Structure
