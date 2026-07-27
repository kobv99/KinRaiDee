# Changelog

## Unreleased

### Added

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

- PR #6 remains Draft.
- New targeted, full-suite, analysis, formatting, diff, and manual web results
  must be recorded from the local Flutter environment before Ready for review.
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
