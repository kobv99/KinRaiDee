# Full Animal & Seafood Taxonomy Expansion - Manifest Audit Report

- Branch: `feature/full-animal-seafood-taxonomy`
- Base commit (approved Branch C): `fdd7d8a7cfe7ce5d245f32d03afcbbaa3db27cff`
- Manifest source of truth (Product Acceptance requirement): `D:\Dev\KinRaiDee_Animal_Seafood_Manifest_114.txt` — 114 numbered entries across 11 categories, plus a binding canonical correction (`chicken_thigh = สะโพกไก่`, `chicken_drumstick = น่องไก่`, kept as separate IDs).
- Implementation surface being verified against that Manifest: `assets/ingredients/thai_ingredients.json` (loaded by `IngredientCatalog` into `CanonicalIngredientRegistry`) plus the migration/search/UI layers built on it.

**Independence of this audit pass:** the `.txt` was re-read directly from disk and re-transcribed independently of the implementation JSON and independently of the pre-existing `_manifest` constant in
`test/core/domain/ingredients/animal_seafood_taxonomy_manifest_test.dart`. The two transcriptions were then diffed line-by-line, category-by-category: they are identical (same 11 category labels, same per-category counts, same 114 names in the same order, same four `X / Y` slash entries). This closes the risk that the test's expected list was reverse-engineered from the implementation it's supposed to be checking. The comparison direction enforced throughout this report is **Manifest (114 rows, from the `.txt`) → resolved against the implementation → exactly 114 distinct selectable canonical IDs**, never the reverse.

## Summary

| Metric | Value |
|---|---|
| Manifest rows | 114 |
| Distinct mapped canonical IDs | 114 |
| Rows mapped to a generic-taxonomyType id | 0 |
| Duplicate ID claims | 0 |
| Missing (unmatched) rows | 0 |
| existing (already in approved Branch C) | 22 |
| migrated (promoted from a generic alias to its own id) | 11 |
| new (freshly authored this branch) | 81 |
| Rows matched via alias, not localized display name | 2 |
| canonicalIngredientMigrationVersion | 5 |

## Per-category counts (expected vs actual)

| Category | Expected | Actual |
|---|---|---|
| หมู | 18 | 18 |
| ไก่ | 14 | 14 |
| เนื้อวัว | 19 | 19 |
| ปลาน้ำจืด | 10 | 10 |
| ปลาทะเล | 10 | 10 |
| ส่วนของปลา | 6 | 6 |
| กุ้ง | 8 | 8 |
| ปู | 7 | 7 |
| ปลาหมึก | 7 | 7 |
| หอย | 9 | 9 |
| สัตว์ทะเลอื่น ๆ | 6 | 6 |

## Missing list

None - all 114 manifest rows resolved to exactly one canonical id.

## Extra list (registry ids that exist but are not part of the 114 manifest)

Generic root ingredients (must remain - they are the broader, non-specific parent; the manifest's specific cuts/species/parts sit alongside them, never replacing them):

| ID | Thai name | taxonomyType |
|---|---|---|
| pork | หมู | generic |
| chicken | ไก่ | generic |
| beef | เนื้อวัว | generic |
| crab | ปู | generic |
| fish | ปลา | generic |
| shrimp | กุ้ง | generic |
| squid | ปลาหมึก | generic |
| shellfish | หอย | generic |

Other pre-existing extras (not in the manifest, preserved from Branch B/C, not deleted):

| ID | Thai name | Reason kept |
|---|---|---|
| moo_yor | หมูยอ | Real, already-shipped product; not named in the manifest's หมู list |
| imitation_crab | ปูอัด | Real, already-shipped product; not named in the manifest's ปู list |

## Display-name-vs-alias audit (Product decision needed)

The following manifest names currently match only through an alias, not the ingredient's localized display name. Per instruction, these were not silently renamed - flagged here for a Product decision (accept as alias-covered, or rename the display name to match the manifest exactly):

| Manifest name | Matched via (alias) | Canonical ID | Current display name |
|---|---|---|---|
| สามชั้น | สามชั้น | pork_belly | หมูสามชั้น |
| ไก่บด | ไก่บด | minced_chicken | ไก่สับ |

Both existed before this branch (Branch B/C authored data) - this branch did not introduce them, only surfaced them via the stronger audit.

## Slash entries (X / Y) - both names belong to one canonical ID

| Manifest line | Localized display name (matched) | Alias | Canonical ID |
|---|---|---|---|
| เนื้อบด / เนื้อสับ | เนื้อบด | เนื้อสับ | minced_beef |
| ขาไก่ / ตีนไก่ | ขาไก่ | ตีนไก่ | chicken_feet |
| ปลาดาบ / ปลากระโทง | ปลาดาบ | ปลากระโทง | hairtail_fish |
| หอยโข่ง / หอยขม | หอยโข่ง | หอยขม | apple_snail |

## Generic substitution fixes (this audit)

| Manifest name | Was (before this fix) | Now | New taxonomyType |
|---|---|---|---|
| หมูชิ้น | alias of `pork` (generic) | own id `pork_piece` | form |
| เนื้อไก่ชิ้น | alias of `chicken` (generic) | own id `chicken_piece` | form |
| เนื้อวัวชิ้น | alias of `beef` (generic) | own id `beef_piece` | form |
| เนื้อปู | alias of `crab` (generic) | own id `crab_meat` | form |

The generic ids `pork`/`chicken`/`beef`/`crab` were not removed - they remain valid, selectable, broader ingredients; they simply no longer count toward the 114 manifest entries.

## Migration rules and version

Correction from the prior draft of this report: `canonicalIngredientMigrationVersion` moved directly `3 -> 5` in this uncommitted working tree (verified against `git show HEAD:.../canonical_ingredient_migration.dart`, which has `= 3`; no commit in this branch's history ever persisted a value of `4`). "Group D" and "Group E" below are a *logical* grouping of migration rules within that single version bump, not two separate shipped versions — the "3->4->5" phrasing in an earlier draft of this report overstated the history and is corrected here.

Semantic migration rules added (`CanonicalIngredientSemanticMigration`, group E), gated by `schemaVersion < 5`:

| Stored canonicalId | Stored name (positive match) | Migrates to |
|---|---|---|
| pork | หมูชิ้น | pork_piece |
| chicken | เนื้อไก่ชิ้น | chicken_piece |
| beef | เนื้อวัวชิ้น | beef_piece |
| crab | เนื้อปู | crab_meat |

Generic records with any other (genuinely generic) stored name are left unchanged. Pantry lots and cooking-history changes (both linked-to-a-lot and orphaned/lot-deleted) are covered by dedicated tests.

This is on top of the migration rules already added earlier in this branch (group D, same version bump lineage 3->4->5): `shrimp`+กุ้งขาว->`whiteleg_shrimp`, `shrimp`+กุ้งแชบ๊วย->`banana_shrimp`, `squid`+หมึกกล้วย->`needle_squid`, `squid`+หมึกหอม->`bigfin_reef_squid`, `shellfish`+หอยแมลงภู่->`green_mussel`, `shellfish`+หอยลาย->`carpet_clam`, `tilapia`+ปลาทับทิม->`red_tilapia`.

## normalizeIngredientKey regression audit

Root cause (found earlier this branch): the shared `normalizeIngredientKey` stripped all Unicode combining marks (Thai tone/vowel signs are category Mn, not L), collapsing distinct words like กั้ง and กุ้ง to the same key. Fix: keep `\p{M}` (marks) in the normalized key - strictly additive (more distinguishing information survives, never less).

Exact resolution (registry.resolve, real bundled registry):

| Query | Resolves to | Result |
|---|---|---|
| กั้ง | mantis_shrimp | PASS |
| กุ้ง | shrimp | PASS |
| ปลาทับทิม | red_tilapia | PASS |
| หมึกกล้วย | needle_squid | PASS |
| หอยลาย | carpet_clam | PASS |

Canonical (substring) search (`CanonicalIngredientSearchService`, real bundled registry):

| Query | Required id(s) present | Result |
|---|---|---|
| น่อง | chicken_drumstick, beef_shank | PASS |
| กั้ง | mantis_shrimp | PASS |
| กุ้ง | shrimp (plus every shrimp-family id whose name/alias literally contains กุ้ง - e.g. whiteleg_shrimp, banana_shrimp, tiger_shrimp, giant_river_prawn, lobster, shrimp_head, shrimp_shell, peeled_shrimp_meat, krill - all correct, substring search is intentionally broad) | PASS |
| ปลาทับทิม | red_tilapia | PASS |
| เนื้อปู | crab_meat (now the only match - the crab generic's เนื้อปู alias was removed as part of the generic-substitution fix) | PASS |

Mark-omitted queries (tone/vowel mark dropped - observational only, per instruction not to invent a new requirement):

| Query | Old behavior (pre-fix, mark-stripping) | New behavior (post-fix, mark-preserving) | Regression? |
|---|---|---|---|
| กัง (drops the tone mark from กั้ง) | ambiguous match: [mantis_shrimp, shrimp] | no match | No - this exact query was never a required/tested example; the fix intentionally trades this narrow recall for eliminating the กั้ง/กุ้ง collision |
| กุง (drops the tone mark from กุ้ง) | matched shrimp (via the same collision) | no match | No - same reasoning |
| นอง (drops the tone mark from น่อง) | no match (the dropped mark already broke substring contiguity under the OLD normalization too) | no match | No - behavior unchanged; the mark sits between two letters in both old and new normalization, so this query never matched either way |

No change was made to search UX beyond the mark-preservation fix itself - this table is a report of actual behavior, not a new feature. No fuzzy-matching or mark-insensitive fallback was added or is recommended by this audit; `กัง`/`กุง`/`นอง` returning no results is reported as current behavior only, not flagged as a defect.

## Registry-wide structural invariants

Each row below is enforced by a dedicated assertion in `test/core/domain/ingredients/animal_seafood_taxonomy_manifest_test.dart`, executed against the real bundled registry (not a fixture), and cross-checked manually against `assets/ingredients/thai_ingredients.json` for this audit pass.

| Invariant | Result | Evidence |
|---|---|---|
| Manifest rows (expected, from the `.txt`) | 114 | independent re-transcription of the `.txt`, diffed against the test's `_manifest` constant - identical |
| Manifest rows (actual, resolved) | 114 | `mapping` has length 114; every row has a non-null `id` |
| Distinct mapped canonical IDs | 114 | `mapping.map((r) => r.id).toSet()` has length 114 |
| Duplicate mappings (two rows -> one ID) | 0 | grouped-by-id check finds no group with length > 1 |
| Generic IDs inside the mapped 114 | 0 | no mapped row has `taxonomyType == generic` |
| Family nodes inside the mapped 114 | 0 | none of the 9 root family IDs appear in the mapped-ID set |
| Missing rows | 0 | see "Missing list" above |
| Normalized identity collisions (any two IDs sharing a `normalizeIngredientKey`-normalized canonicalName/localizedName/alias) | 0 | `_identityOwners(..., normalized: true)` finds no key owned by >1 ID - this is the check that would have caught the กั้ง/กุ้ง mark-stripping collision before the fix |
| Orphan parents (parentId pointing at a non-existent ID) | 0 | every `ingredient.parentId` resolves via `registry.byId`; the registry constructor itself also throws on this at load time (`missing_parent_ingredient`) |
| Taxonomy cycles | 0 | registry constructor throws on a circular parent chain (`circular_ingredient_parent`) at construction time - a cycle would fail every test, not just a dedicated one |
| Every mapped ID reachable from exactly one taxonomy root | Yes, all 114 | `rootFamilyIds.intersection(ancestorIdsFor(id))` has length exactly 1 for every mapped row |
| Every selectable ingredient (not just the 114) reachable from at most one root | Yes | same check, `<=1`, run over the full registry (229 ingredients) |
| Every `defaultPantryQuantity` finite and > 0 | Yes, all present values | checked for every mapped row that defines one |
| Every default/purchase/preferred/recommended unit resolves | Yes, all 114 | checked against the real `UnitConversionEngine` |
| Every localized display name searchable (substring match against itself) | Yes, all 114 manifest names (both terms of each slash entry) | checked against `registry.ingredients` search-name set |

Generic IDs (`pork`/`chicken`/`beef`/`fish`/`shrimp`/`crab`/`squid`/`shellfish`) and the 9 family nodes were independently re-verified against the raw JSON for this audit pass (not just the test): each generic ID's `aliases` array was inspected directly and confirmed to no longer contain any of the four promoted names (`หมูชิ้น`, `เนื้อไก่ชิ้น`, `เนื้อวัวชิ้น`, `เนื้อปู`), and each of the 114 mapped IDs was hand-matched against its JSON entry's `name`/`aliases`/`taxonomyType`/`parentId` fields.

## หมู (18)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | หมูสับ | minced_pork | หมูสับ | form | pork_family | name | existing |
| 02 | หมูชิ้น | pork_piece | หมูชิ้น | form | pork_family | name | migrated |
| 03 | สันในหมู | pork_tenderloin | สันในหมู | cut | pork_family | name | existing |
| 04 | สันนอกหมู | pork_loin | สันนอกหมู | cut | pork_family | name | new |
| 05 | สันคอหมู | pork_neck | สันคอหมู | cut | pork_family | name | existing |
| 06 | สามชั้น | pork_belly | หมูสามชั้น | cut | pork_family | alias | existing |
| 07 | ซี่โครงหมู | pork_ribs | ซี่โครงหมู | cut | pork_family | name | existing |
| 08 | กระดูกอ่อนหมู | pork_cartilage | กระดูกอ่อนหมู | organ | pork_family | name | new |
| 09 | ขาหมู | pork_leg | ขาหมู | cut | pork_family | name | new |
| 10 | หนังหมู | pork_skin | หนังหมู | organ | pork_family | name | new |
| 11 | ตับหมู | pork_liver | ตับหมู | organ | pork_family | name | existing |
| 12 | ไส้หมู | pork_intestine | ไส้หมู | organ | pork_family | name | new |
| 13 | กระเพาะหมู | pork_stomach | กระเพาะหมู | organ | pork_family | name | new |
| 14 | หัวใจหมู | pork_heart | หัวใจหมู | organ | pork_family | name | new |
| 15 | ลิ้นหมู | pork_tongue | ลิ้นหมู | organ | pork_family | name | new |
| 16 | หูหมู | pork_ear | หูหมู | organ | pork_family | name | new |
| 17 | เลือดหมู | pork_blood | เลือดหมู | organ | pork_family | name | new |
| 18 | มันหมู | pork_fat | มันหมู | organ | pork_family | name | new |

## ไก่ (14)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | ไก่ทั้งตัว | chicken_whole | ไก่ทั้งตัว | whole | chicken_family | name | new |
| 02 | เนื้อไก่ชิ้น | chicken_piece | เนื้อไก่ชิ้น | form | chicken_family | name | migrated |
| 03 | อกไก่ | chicken_breast | อกไก่ | cut | chicken_family | name | existing |
| 04 | สันในไก่ | chicken_tenderloin | สันในไก่ | cut | chicken_family | name | new |
| 05 | สะโพกไก่ | chicken_thigh | สะโพกไก่ | cut | chicken_family | name | existing |
| 06 | น่องไก่ | chicken_drumstick | น่องไก่ | cut | chicken_family | name | existing |
| 07 | ปีกไก่ | chicken_wing | ปีกไก่ | cut | chicken_family | name | existing |
| 08 | ขาไก่ / ตีนไก่ | chicken_feet | ขาไก่ | organ | chicken_family | name | new |
| 09 | โครงไก่ | chicken_carcass | โครงไก่ | organ | chicken_family | name | new |
| 10 | หนังไก่ | chicken_skin | หนังไก่ | organ | chicken_family | name | new |
| 11 | ตับไก่ | chicken_liver | ตับไก่ | organ | chicken_family | name | existing |
| 12 | กึ๋นไก่ | chicken_gizzard | กึ๋นไก่ | organ | chicken_family | name | existing |
| 13 | หัวใจไก่ | chicken_heart | หัวใจไก่ | organ | chicken_family | name | new |
| 14 | ไก่บด | minced_chicken | ไก่สับ | form | chicken_family | alias | existing |

## เนื้อวัว (19)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | เนื้อวัวชิ้น | beef_piece | เนื้อวัวชิ้น | form | beef_family | name | migrated |
| 02 | เนื้อบด / เนื้อสับ | minced_beef | เนื้อบด | form | beef_family | name | existing |
| 03 | สันในวัว | beef_tenderloin | สันในวัว | cut | beef_family | name | new |
| 04 | สันนอกวัว | beef_sirloin | สันนอกวัว | cut | beef_family | name | new |
| 05 | ริบอาย | beef_ribeye | ริบอาย | cut | beef_family | name | new |
| 06 | ทีโบน | beef_tbone | ทีโบน | cut | beef_family | name | new |
| 07 | เนื้อเสือร้องไห้ | beef_hanger_steak | เนื้อเสือร้องไห้ | cut | beef_family | name | new |
| 08 | เนื้อสะโพก | beef_rump | เนื้อสะโพก | cut | beef_family | name | new |
| 09 | เนื้อน่องลาย | beef_shank | เนื้อน่องลาย | cut | beef_family | name | existing |
| 10 | เนื้อหน้าอก | beef_brisket | เนื้อหน้าอก | cut | beef_family | name | new |
| 11 | ซี่โครงวัว | beef_short_rib | ซี่โครงวัว | cut | beef_family | name | new |
| 12 | หางวัว | beef_oxtail | หางวัว | cut | beef_family | name | new |
| 13 | ลิ้นวัว | beef_tongue | ลิ้นวัว | organ | beef_family | name | new |
| 14 | ตับวัว | beef_liver | ตับวัว | organ | beef_family | name | new |
| 15 | ไส้วัว | beef_intestine | ไส้วัว | organ | beef_family | name | new |
| 16 | ผ้าขี้ริ้ว | beef_tripe | ผ้าขี้ริ้ว | organ | beef_family | name | new |
| 17 | เอ็นวัว | beef_tendon | เอ็นวัว | organ | beef_family | name | new |
| 18 | ม้ามวัว | beef_spleen | ม้ามวัว | organ | beef_family | name | new |
| 19 | กระดูกวัว | beef_bone | กระดูกวัว | organ | beef_family | name | new |

## ปลาน้ำจืด (10)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | ปลานิล | tilapia | ปลานิล | species | freshwater_fish_family | name | existing |
| 02 | ปลาทับทิม | red_tilapia | ปลาทับทิม | species | freshwater_fish_family | name | migrated |
| 03 | ปลาช่อน | snakehead | ปลาช่อน | species | freshwater_fish_family | name | existing |
| 04 | ปลาดุก | catfish | ปลาดุก | species | freshwater_fish_family | name | existing |
| 05 | ปลาตะเพียน | silver_barb | ปลาตะเพียน | species | freshwater_fish_family | name | new |
| 06 | ปลาคัง | pla_kang | ปลาคัง | species | freshwater_fish_family | name | new |
| 07 | ปลาบึก | mekong_giant_catfish | ปลาบึก | species | freshwater_fish_family | name | new |
| 08 | ปลาเนื้ออ่อน | pla_nuea_on | ปลาเนื้ออ่อน | species | freshwater_fish_family | name | new |
| 09 | ปลากราย | knife_fish | ปลากราย | species | freshwater_fish_family | name | new |
| 10 | ปลาไหล | freshwater_eel | ปลาไหล | species | freshwater_fish_family | name | new |

## ปลาทะเล (10)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | ปลากะพง | sea_bass | ปลากะพง | species | sea_fish_family | name | existing |
| 02 | ปลาเก๋า | grouper | ปลาเก๋า | species | sea_fish_family | name | new |
| 03 | ปลาทู | mackerel | ปลาทู | species | sea_fish_family | name | existing |
| 04 | ปลาอินทรี | spanish_mackerel | ปลาอินทรี | species | sea_fish_family | name | new |
| 05 | ปลาสำลี | pla_samli | ปลาสำลี | species | sea_fish_family | name | new |
| 06 | ปลาจะละเม็ด | pomfret | ปลาจะละเม็ด | species | sea_fish_family | name | new |
| 07 | ปลาแซลมอน | salmon | ปลาแซลมอน | species | sea_fish_family | name | existing |
| 08 | ปลาทูน่า | tuna | ปลาทูน่า | species | sea_fish_family | name | new |
| 09 | ปลาซาบะ | saba_mackerel | ปลาซาบะ | species | sea_fish_family | name | new |
| 10 | ปลาดาบ / ปลากระโทง | hairtail_fish | ปลาดาบ | species | sea_fish_family | name | new |

## ส่วนของปลา (6)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | เนื้อปลาแล่ | fish_fillet | เนื้อปลาแล่ | form | fish_family | name | existing |
| 02 | หัวปลา | fish_head | หัวปลา | organ | fish_family | name | new |
| 03 | ท้องปลา | fish_belly | ท้องปลา | organ | fish_family | name | new |
| 04 | ไข่ปลา | fish_roe | ไข่ปลา | organ | fish_family | name | new |
| 05 | หนังปลา | fish_skin | หนังปลา | organ | fish_family | name | new |
| 06 | ก้างและกระดูกปลา | fish_bones | ก้างและกระดูกปลา | organ | fish_family | name | new |

## กุ้ง (8)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | กุ้งขาว | whiteleg_shrimp | กุ้งขาว | species | shrimp_family | name | migrated |
| 02 | กุ้งก้ามกราม | giant_river_prawn | กุ้งก้ามกราม | species | shrimp_family | name | new |
| 03 | กุ้งแชบ๊วย | banana_shrimp | กุ้งแชบ๊วย | species | shrimp_family | name | migrated |
| 04 | กุ้งลายเสือ | tiger_shrimp | กุ้งลายเสือ | species | shrimp_family | name | new |
| 05 | กุ้งมังกร | lobster | กุ้งมังกร | species | shrimp_family | name | new |
| 06 | เนื้อกุ้งแกะ | peeled_shrimp_meat | เนื้อกุ้งแกะ | form | shrimp_family | name | new |
| 07 | หัวกุ้ง | shrimp_head | หัวกุ้ง | organ | shrimp_family | name | new |
| 08 | เปลือกกุ้ง | shrimp_shell | เปลือกกุ้ง | organ | shrimp_family | name | new |

## ปู (7)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | ปูทะเล | mud_crab | ปูทะเล | species | crab_family | name | new |
| 02 | ปูม้า | blue_swimming_crab | ปูม้า | species | crab_family | name | new |
| 03 | ปูไข่ | roe_crab | ปูไข่ | species | crab_family | name | new |
| 04 | ปูนิ่ม | soft_shell_crab | ปูนิ่ม | product | crab_family | name | new |
| 05 | เนื้อปู | crab_meat | เนื้อปู | form | crab_family | name | migrated |
| 06 | กรรเชียงปู | crab_claw | กรรเชียงปู | organ | crab_family | name | new |
| 07 | มันปู | crab_fat | มันปู | organ | crab_family | name | new |

## ปลาหมึก (7)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | หมึกกล้วย | needle_squid | หมึกกล้วย | species | squid_family | name | migrated |
| 02 | หมึกหอม | bigfin_reef_squid | หมึกหอม | species | squid_family | name | migrated |
| 03 | หมึกกระดอง | cuttlefish | หมึกกระดอง | species | squid_family | name | new |
| 04 | หมึกสาย | octopus | หมึกสาย | species | squid_family | name | new |
| 05 | หนวดหมึก | squid_tentacle | หนวดหมึก | organ | squid_family | name | new |
| 06 | ไข่หมึก | squid_roe | ไข่หมึก | organ | squid_family | name | new |
| 07 | หมึกแห้ง | dried_squid | หมึกแห้ง | product | squid_family | name | new |

## หอย (9)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | หอยแมลงภู่ | green_mussel | หอยแมลงภู่ | species | shellfish_family | name | migrated |
| 02 | หอยนางรม | oyster | หอยนางรม | species | shellfish_family | name | new |
| 03 | หอยแครง | cockle | หอยแครง | species | shellfish_family | name | new |
| 04 | หอยลาย | carpet_clam | หอยลาย | species | shellfish_family | name | migrated |
| 05 | หอยหวาน | spotted_babylon | หอยหวาน | species | shellfish_family | name | new |
| 06 | หอยเชลล์ | scallop | หอยเชลล์ | species | shellfish_family | name | new |
| 07 | หอยเป๋าฮื้อ | abalone | หอยเป๋าฮื้อ | species | shellfish_family | name | new |
| 08 | หอยหลอด | razor_clam | หอยหลอด | species | shellfish_family | name | new |
| 09 | หอยโข่ง / หอยขม | apple_snail | หอยโข่ง | species | shellfish_family | name | new |

## สัตว์ทะเลอื่น ๆ (6)

| # | Manifest name | Canonical ID | Display name | taxonomyType | parentId | Matched via | Status |
|---|---|---|---|---|---|---|---|
| 01 | กั้ง | mantis_shrimp | กั้ง | species | other_seafood_family | name | new |
| 02 | กุ้งเคย | krill | กุ้งเคย | species | other_seafood_family | name | new |
| 03 | แมงกะพรุน | jellyfish | แมงกะพรุน | species | other_seafood_family | name | new |
| 04 | ปลิงทะเล | sea_cucumber | ปลิงทะเล | species | other_seafood_family | name | new |
| 05 | เม่นทะเล | sea_urchin | เม่นทะเล | species | other_seafood_family | name | new |
| 06 | ไข่แมงดาทะเล | horseshoe_crab_roe | ไข่แมงดาทะเล | organ | other_seafood_family | name | new |

## Automated-test evidence (this audit pass)

Commands run against the working tree, in order, with verbatim results:

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | `Formatted 298 files (0 changed)`, exit 0 |
| `flutter analyze` | `No issues found!`, exit 0 |
| `flutter test` | `+559`, `All tests passed!`, exit 0 (run twice for confirmation, identical result both times) |
| `flutter build web` | `√ Built build\web`, exit 0 |
| `git diff --check` | no output, exit 0 |

559 is the total automated test count across the whole suite (unit, widget, and integration-style tests), not just the manifest-specific tests. `test/core/domain/ingredients/animal_seafood_taxonomy_manifest_test.dart` alone contributes the structural/content assertions itemized in "Registry-wide structural invariants" above.

## Exact modified and untracked files (this audit pass)

Modified (tracked, uncommitted):
- `assets/ingredients/thai_ingredients.json`
- `lib/core/domain/ingredients/canonical_ingredient_registry.dart`
- `lib/features/pantry/application/canonical_ingredient_migration.dart`
- `lib/features/pantry/application/canonical_ingredient_semantic_migration.dart`
- `lib/features/pantry/presentation/pages/ingredient_picker_entry_page.dart`
- `lib/features/recipe/data/pantry_catalog_canonical_definitions.dart`
- `test/features/pantry/application/canonical_ingredient_semantic_migration_test.dart`
- `test/features/pantry/pantry_catalog_integrity_test.dart`
- `test/features/pantry/presentation/pages/ingredient_picker_entry_page_test.dart`
- `test/features/pantry/presentation/providers/ingredient_picker_providers_test.dart`
- `test/features/recipe/data/animal_seafood_taxonomy_content_test.dart`
- `test/features/recipe/data/migrated_alias_regression_test.dart`

Untracked (new):
- `docs/diagnostics/full_animal_seafood_taxonomy_manifest_audit_2026-08-05.md` (this report)
- `test/core/domain/ingredients/animal_seafood_taxonomy_manifest_test.dart`

## Product Acceptance status

**Product Acceptance: PASS.** Automated evidence above (structural invariants + 559/559 passing tests + clean format/analyze/build) was independently re-verified in a follow-up CTO-support review (114/114 structural proof re-derived directly from `D:\Dev\KinRaiDee_Animal_Seafood_Manifest_114.txt`, migration version history re-checked with `git log -p --all`, focused re-runs of the manifest test (31/31) and semantic migration test (39/39)). The CEO subsequently completed Live UAT (all cases PASS) and granted Product Acceptance: PASS for this branch, including explicit acceptance of the two alias-only display-name cases (`สามชั้น`, `ไก่บด`) as-is and the mark-omitted search queries (`กัง`, `กุง`, `นอง`) returning zero results as current, acceptable behavior for this branch. One non-blocking follow-up was noted for a future ticket: `PantryNotifier._canonicalize` (`lib/core/providers/pantry_provider.dart`) can bypass `CanonicalIngredientSemanticMigration` on the runtime add/edit path — a pre-existing architectural gap inherited from groups A/B/C, not introduced or worsened by this branch.
