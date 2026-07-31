# Shopping UI and Pantry Completion Workflow

## Product Direction

Shopping is an actionable task list, not a historical archive. It contains only
unfinished work. Completing an item removes it from Shopping immediately and
records the purchase through the durable inventory transaction journal.

Pantry represents the current inventory snapshot. Completing Shopping must
merge with the existing canonical Pantry ingredient whenever the units are
convertible. It must not create duplicate canonical Pantry records.

Pricing, retailer identity, package sizing, barcode scanning, cloud
synchronization, AI, and Recommendation behavior remain outside SF-003.

## Screens and States

`ShoppingPage` renders:

| State | UI behavior |
|---|---|
| Loading | Centered progress indicator while the local projection loads |
| Error | Non-destructive error message and retry action |
| No list | Recipe-generation explanation and primary call to action |
| Active list | List overview, search, category/Recipe filters, sorting, and active items |
| Completed list | Celebration empty state: `🎉 ไม่มีรายการที่ต้องซื้อแล้ว` and `พร้อมทำอาหารได้เลย` |
| Mutating | Thin progress indicator; affected controls remain disabled until durable completion |

There is no Completed tab, Completed section, archive action, or restore action.
Legacy purchased/archived items remain readable in storage for compatibility but
are excluded from the actionable Shopping projection and from regenerated
lists.

Each active item displays its canonical presentation, quantity and localized
unit, category, Recipe sources, compatible non-expired Pantry availability, and
one primary action: `เก็บเข้าตู้`.

## Generate from Recipes

```mermaid
flowchart TD
    A["Open Shopping"] --> B["Choose one or more Recipes"]
    B --> C["Adjust servings"]
    C --> D["Generate deterministic preview"]
    D --> E{"Confirm?"}
    E -- "No" --> B
    E -- "Yes" --> F["ShoppingMutation.upsert"]
    F --> G["InventoryTransactionCoordinator"]
    G --> H["Durable journal and envelope commit"]
    H --> I["Refresh active Shopping projection"]
```

`ShoppingEngine.generate` carries forward active intent only. Legacy completed
or archived records are not copied back into a regenerated Shopping list.
Canonical duplicates are aggregated before confirmation and no optimistic list
is published.

## Complete Shopping Item

The UI triggers one application action. It does not resolve ingredients, convert
units, merge Pantry, construct Purchase History, or remove Shopping records.

```mermaid
sequenceDiagram
    participant User
    participant UI as ShoppingPage
    participant Controller as ShoppingCompletionController
    participant Coordinator as ShoppingCompletionCoordinator
    participant Repository as InventoryCommitRepository
    participant Journal as Durable journal
    participant State as Riverpod projections

    User->>UI: เก็บเข้าตู้
    UI->>Controller: complete(listId, revision, itemId)
    Controller->>Coordinator: completeItem
    Coordinator->>Coordinator: Resolve canonical ingredient
    Coordinator->>Coordinator: Validate and convert units
    Coordinator->>Coordinator: Merge/consolidate Pantry
    Coordinator->>Coordinator: Remove Shopping item
    Coordinator->>Repository: Commit before/after envelope atomically
    Repository->>Journal: Persist transaction and snapshots
    Journal-->>Repository: Durable result
    Repository-->>Coordinator: Committed snapshot
    Coordinator-->>Controller: InventoryTransactionResult
    Controller->>State: Publish Pantry; invalidate Shopping and Purchase History
    State-->>UI: Item disappears immediately
```

After success, the screen shows `✓ เพิ่มเข้าตู้แล้ว` with a seven-second Undo
SnackBar. The Shopping item is not retained as a completed record.

## Canonical Pantry Merge

Merge resolution order is:

1. `canonicalIngredientId` through registry redirect resolution;
2. stable registry key resolution;
3. localized/alias registry resolution.

Display-name equality is never used as the merge rule. A display name may only
be supplied to the canonical registry as a legacy alias fallback.

For the resolved canonical ingredient:

- no existing Pantry candidate: convert to the canonical default inventory unit
  and create one Pantry record;
- one existing candidate: convert the purchase into its canonical unit and add
  the quantity;
- multiple existing canonical duplicates: convert every compatible candidate to
  one deterministic primary unit, consolidate them into one record, then add the
  purchase quantity;
- incompatible or unknown units: return a typed failure and leave Shopping,
  Pantry, and Purchase History unchanged.

Examples:

- `6 ฟอง + 2 ฟอง = 8 ฟอง`;
- `0.4 L + 0.25 L = 0.65 L`;
- `0.4 L + 100 ml + 250 ml = 0.75 L` and one Pantry record.

## Purchase History

`PurchaseHistoryEntry` is a read model projected from committed
`shoppingPurchase` transaction records. The durable journal already owns the
complete before/after envelopes required for recovery and Undo, so the workflow
does not add another Hive box or duplicate persistence path.

Each projected record contains:

- purchase timestamp;
- resolved canonical ingredient identity and display name;
- purchased quantity and unit;
- source Recipe IDs;
- Shopping list and item IDs;
- Pantry transaction ID; and
- affected Pantry lot IDs.

Legacy completed Shopping records with embedded purchase receipts remain
projectable when their journal record is unavailable. They are never shown in
the actionable Shopping UI.

## Undo

Undo uses the original purchase transaction ID. The coordinator reads the
original before/after envelopes, verifies that affected Pantry lots have not
changed since completion, and commits a new `undoShoppingPurchase` transaction
that atomically:

- restores only the Pantry records touched by the purchase;
- restores the Shopping item as active;
- removes the projected Purchase History entry.

If Pantry changed after the purchase or an equivalent active Shopping item was
recreated, Undo fails closed rather than overwriting newer state.

## Search, Filter, and Sort

`ShoppingViewProjector` is an active-only in-memory projection:

- search matches canonical names, aliases, localized names, keywords, display
  names, and canonical IDs;
- filters support category and Recipe source;
- sorting supports category, alphabetical name, and Recipe source; and
- Pantry availability converts compatible lots to the Shopping item unit and
  ignores expired or empty lots.

## Compatibility

- Existing envelope and journal versions remain readable.
- Existing purchased/archived Shopping records are retained in storage but hidden
  from active Shopping.
- Existing `markPurchased`, `markUnpurchased`, archive, and restore domain APIs
  remain available for backward-compatible data/tests; the current Shopping UI
  does not invoke them.
- Purchase History is derived from durable transaction snapshots and therefore
  survives restart without a second persistence schema.

## Test Evidence

- `test/features/shopping/shopping_completion_coordinator_test.dart`
- `test/features/shopping/shopping_ui_test.dart`
- `test/features/shopping/shopping_ui_integration_test.dart`
- `test/features/shopping/shopping_view_provider_test.dart`
- existing Shopping Engine and transaction regression suites

Coverage includes canonical merge, unit conversion, duplicate consolidation,
incompatible-unit failure, Purchase History projection, active-item removal,
restart durability, full Undo, active-only search/filter/sort, failed storage,
and duplicate-safe Recipe regeneration.

## Verification Status

Implementation is on Draft PR #6. Automated and manual results for this product
direction must be recorded only after running on the local Flutter toolchain.
The PR must remain Draft until formatting, analysis, the full test suite, and
manual web verification are complete.
