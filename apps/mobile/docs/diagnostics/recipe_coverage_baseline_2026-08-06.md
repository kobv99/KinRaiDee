# Recipe Coverage Baseline Audit

> Phase 2 audit-only baseline. No recipe content, compatibility metadata, recommendation behavior, Pantry behavior, or taxonomy data was modified to produce this report.

## 1. Audit identity

- Branch: `audit/recipe-coverage-baseline`
- Base SHA: `2932be8e38dad91c996039049b5f038fcf020fb9`
- Generation date: `2026-08-06`
- Registry source: `IngredientCatalog().loadRegistry()`
- Recipe source: `LocalRecipeDataSource().loadRecipes()` (all current default asset packs)
- Production services exercised: `MainIngredientCompatibilityService`, `RecipeReadinessService`, `RecipeCandidateService.evaluateAllRecipes`, `SmartRecommendationEngine`

## 2. Dataset summary

| Metric | Value |
|---|---|
| Total registry nodes | 229 |
| Selectable main ingredients | 218 |
| Family/category nodes | 11 |
| Total recipes | 165 |

Recipe count by pack:

| Pack | Count |
|---|---|
| beef | 20 |
| chicken | 20 |
| egg | 20 |
| fish | 20 |
| mackerel | 7 |
| pork | 20 |
| salted_egg | 12 |
| shrimp | 20 |
| squid | 20 |
| thai | 6 |

Recipe count by hero canonical ID:

| Hero canonical ID | Count |
|---|---|
| beef | 20 |
| chicken | 21 |
| egg | 21 |
| fish | 20 |
| mackerel | 7 |
| pork | 22 |
| rice | 1 |
| salted_egg | 12 |
| shrimp | 20 |
| squid | 20 |
| tofu | 1 |

## 3. Coverage summary

> Primary classification is based **only** on eligible tiers (exact/preferred/compatible/substitute/family). No exclusion reason — including `unverifiedFamily`, which fires whenever a recipe declares support for *other* families but not this ingredient's — ever changes these three counts. See section 3b for the exclusion overlay.

| Metric | Value |
|---|---|
| DIRECT_COVERAGE | 11 |
| ADAPTABLE_ONLY | 0 |
| NO_COVERAGE | 207 |
| Ingredients with >=1 exact | 11 |
| Ingredients with >=1 preferred | 0 |
| Ingredients with >=1 compatible | 1 |
| Ingredients with >=1 substitute | 0 |
| Ingredients with >=1 family | 0 |
| Total eligible exact pairs | 146 |
| Total eligible preferred pairs | 0 |
| Total eligible compatible pairs | 6 |
| Total eligible substitute pairs | 0 |
| Total eligible family pairs | 0 |

## 3b. Exclusion diagnostics (overlay, not a coverage tier)

> Every recipe/ingredient pair that did **not** reach an eligible tier falls into exactly one of these six reasons. This table is diagnostic only — it never changes section 3's counts. In particular, `unverifiedFamily` (the recipe supports other families, not this one) and `noMatch` (the recipe simply never mentions this ingredient) are expected to be large for most ingredients and do not by themselves indicate a defect.

| Exclusion reason | Ingredients with >=1 occurrence | Total ingredient-recipe pairs |
|---|---|---|
| explicitlyExcluded | 1 | 13 |
| incompatibleForm | 215 | 5764 |
| incompatibleTexture | 4 | 56 |
| incompatibleCookingMethod | 1 | 1 |
| unverifiedFamily | 3 | 39 |
| noMatch | 218 | 29945 |

### Three-way split of the incompatible*/explicitlyExcluded reasons

> Production returns the *same* exclusion-reason value (`incompatibleForm`/`incompatibleTexture`/`incompatibleCookingMethod`) whether an ingredient's declared profile genuinely conflicts with a recipe's constraint, or the ingredient simply has no profile data on that dimension at all. This audit distinguishes the two using the canonical profile fields already available when each row is built — it never changes production behavior. `explicitlyExcluded` is unambiguous by construction (an authored id on a recipe's `excludedIngredientIds`) and is never split.
>
> Form and texture use a strict "no data means no match" default: an empty `ingredientForms`/`textures` profile still gets excluded (as PROFILE_INCOMPLETE) when a recipe requires a form/texture. Cooking method is asymmetric: production only raises `incompatibleCookingMethod` when the ingredient DOES have declared `supportedCookingMethods` that fail to intersect the recipe's required methods — an ingredient with no declared methods is never excluded on that basis at all, so PROFILE_INCOMPLETE(cookingMethod) is always 0, by production design, not an audit gap (verified directly against `MainIngredientCompatibilityService.evaluate`, not assumed).

| Category | Ingredients | Pairs (by dimension) |
|---|---|---|
| EXPLICIT_ID_BLOCK (explicitlyExcluded — always deliberate, ingredient-specific) | 1 | total: 13 |
| CONSTRAINT_MISMATCH (profile data exists and genuinely conflicts) | 6 | form: 40, texture: 56, cookingMethod: 1 |
| PROFILE_INCOMPLETE (no profile data on that dimension — a data-completeness gap, not a deliberate rejection) | 212 | form: 5724, texture: 0, cookingMethod: 0 |

## 4. Integrity findings

| Finding | Count |
|---|---|
| Invalid canonical references | 0 |
| Invalid family references | 20 |
| Duplicate metadata references | 0 |
| Conflicting metadata | 7 |
| Unknown form tokens (recipe-declared, absent from any ingredient profile) | 0 |
| Unknown cooking-method tokens (recipe-declared, absent from any ingredient profile) | 3 |
| Duplicate recipe IDs | 0 |
| Invalid primary/hero IDs | 0 |

| Code | Recipe ID | Field | Value | Detail |
|---|---|---|---|---|
| invalid_family_reference | fish_01 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_02 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_03 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_04 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_05 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_06 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_07 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_08 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_09 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_10 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_11 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_12 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_13 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_14 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_15 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_16 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_17 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_18 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_19 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| invalid_family_reference | fish_20 | ingredientFamilyIds | fish | Id resolves to a non-family node (nodeType=ingredient). |
| conflicting_metadata | mackerel_01 | exactIngredientIds+preferredIngredientIds | mackerel | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| conflicting_metadata | mackerel_02 | exactIngredientIds+preferredIngredientIds | mackerel | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| conflicting_metadata | mackerel_03 | exactIngredientIds+preferredIngredientIds | mackerel | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| conflicting_metadata | mackerel_04 | exactIngredientIds+preferredIngredientIds | mackerel | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| conflicting_metadata | mackerel_05 | exactIngredientIds+preferredIngredientIds | mackerel | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| conflicting_metadata | mackerel_06 | exactIngredientIds+preferredIngredientIds | mackerel | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| conflicting_metadata | mackerel_07 | exactIngredientIds+preferredIngredientIds | mackerel | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |

Unknown cooking-method tokens: คลุก, คั่ว, อบ

### Grouped by likely root cause (informational — does not replace or weaken the per-recipe findings above)

> Each row below groups findings that share the same (code, field, value) across multiple recipes. `sourceScope: pack_default_likely` means every affected recipe belongs to the same recipe pack — a strong signal (not a proof) that one shared pack-level default is the true root cause, so a content fix likely needs to happen once in `probableSourceFile`, not once per affected recipe. This audit branch does not modify that file.

| Code | Field | Value | Manifestations | Source scope | Probable source file |
|---|---|---|---|---|---|
| conflicting_metadata | exactIngredientIds+preferredIngredientIds | mackerel | 7 | pack_default_likely | assets/recipes/mackerel.json |
| invalid_family_reference | ingredientFamilyIds | fish | 20 | pack_default_likely | assets/recipes/fish.json |

## 5. Full selectable-main-ingredient table

| canonicalId | displayName | category | taxonomyType | parentId | rootId | exact | preferred | compatible | substitute | family | directRecipeCount | adaptableRecipeCount | classification | ingredientForms# | textures# | cookingMethods# | explicitIdBlock | constraintMismatch | profileIncomplete | sampleDirectRecipeIds | sampleAdaptableRecipeIds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| abalone | หอยเป๋าฮื้อ | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| apple_snail | หอยโข่ง | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| bacon | เบคอน | protein | product |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| banana_shrimp | กุ้งแชบ๊วย | seafood | species | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef | เนื้อวัว | protein | generic | beef_family | beef_family | 20 | 0 | 0 | 0 | 0 | 20 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | beef_01, beef_02, beef_03, beef_04, beef_05 | _(none)_ |
| beef_bone | กระดูกวัว | protein | organ | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_brisket | เนื้อหน้าอก | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_hanger_steak | เนื้อเสือร้องไห้ | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_intestine | ไส้วัว | protein | organ | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_liver | ตับวัว | protein | organ | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_oxtail | หางวัว | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_piece | เนื้อวัวชิ้น | protein | form | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_ribeye | ริบอาย | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_rump | เนื้อสะโพก | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_shank | เนื้อน่องลาย | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_short_rib | ซี่โครงวัว | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_sirloin | สันนอกวัว | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_spleen | ม้ามวัว | protein | organ | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_tbone | ทีโบน | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_tenderloin | สันในวัว | protein | cut | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_tendon | เอ็นวัว | protein | organ | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_tongue | ลิ้นวัว | protein | organ | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| beef_tripe | ผ้าขี้ริ้ว | protein | organ | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| bigfin_reef_squid | หมึกหอม | seafood | species | squid_family | squid_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| blue_swimming_crab | ปูม้า | seafood | species | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| bread | ขนมปัง | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| breadcrumbs | เกล็ดขนมปัง | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| broccoli | บรอกโคลี | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| brussels_sprout_shoot | แขนง | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| butter | เนยสด | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cabbage | กะหล่ำปลี | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| canned_fish | ปลากระป๋อง | seafood | product |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| canned_tuna | ทูน่ากระป๋อง | seafood | product |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| carpet_clam | หอยลาย | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| carrot | แครอท | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cashew | เม็ดมะม่วงหิมพานต์ | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| catfish | ปลาดุก | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 2 | 1 | 4 | 0 | 27 | 0 | _(none)_ | _(none)_ |
| cauliflower | กะหล่ำดอก | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| celery | ขึ้นฉ่าย | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| century_egg | ไข่เยี่ยวม้า | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cheese | ชีส | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken | ไก่ | protein | generic | chicken_family | chicken_family | 21 | 0 | 0 | 0 | 0 | 21 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 | _(none)_ |
| chicken_breast | อกไก่ | protein | cut | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_carcass | โครงไก่ | protein | organ | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_drumstick | น่องไก่ | protein | cut | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_feet | ขาไก่ | protein | organ | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_gizzard | กึ๋นไก่ | protein | organ | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_heart | หัวใจไก่ | protein | organ | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_liver | ตับไก่ | protein | organ | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_piece | เนื้อไก่ชิ้น | protein | form | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_skin | หนังไก่ | protein | organ | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_tenderloin | สันในไก่ | protein | cut | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_thigh | สะโพกไก่ | protein | cut | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_whole | ไก่ทั้งตัว | protein | whole | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chicken_wing | ปีกไก่ | protein | cut | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chili | พริก | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chili_paste | น้ำพริกเผา | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| chinese_cabbage | ผักกาดขาว | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cockle | หอยแครง | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| coconut_milk | กะทิ | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| condensed_milk | นมข้นหวาน | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cooking_oil | น้ำมันพืช | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| coriander | ผักชี | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| corn | ข้าวโพด | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| crab | ปู | seafood | generic | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| crab_claw | กรรเชียงปู | seafood | organ | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| crab_fat | มันปู | seafood | organ | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| crab_meat | เนื้อปู | seafood | form | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cream | ครีม | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| crispy_flour | แป้งทอดกรอบ | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cucumber | แตงกวา | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| cuttlefish | หมึกกระดอง | seafood | species | squid_family | squid_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| dark_soy_sauce | ซีอิ๊วดำ | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| dried_chili | พริกแห้ง | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| dried_squid | หมึกแห้ง | seafood | product | squid_family | squid_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| duck | เป็ด | protein | generic |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| duck_egg | ไข่เป็ด | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| edamame | ถั่วแระ | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| egg | ไข่ไก่ | protein |  |  |  | 21 | 0 | 0 | 0 | 0 | 21 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | egg_01, egg_02, egg_03, egg_04, egg_05 | _(none)_ |
| evaporated_milk | นมข้นจืด | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fermented_soybean_paste | เต้าเจี้ยว | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fish | ปลา | seafood | generic | fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fish_belly | ท้องปลา | seafood | organ | fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fish_bones | ก้างและกระดูกปลา | seafood | organ | fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fish_fillet | เนื้อปลาแล่ | seafood | form | fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 2 | 1 | 0 | 0 | 14 | 0 | _(none)_ | _(none)_ |
| fish_head | หัวปลา | seafood | organ | fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fish_roe | ไข่ปลา | seafood | organ | fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fish_sauce | น้ำปลา | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| fish_skin | หนังปลา | seafood | organ | fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| flour | แป้งสาลี | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| freshwater_eel | ปลาไหล | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| galangal | ข่า | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| garlic | กระเทียม | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| giant_river_prawn | กุ้งก้ามกราม | seafood | species | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| ginger | ขิง | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| glass_noodle | วุ้นเส้น | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| green_mussel | หอยแมลงภู่ | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| green_pea | ถั่วลันเตา | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| grouper | ปลาเก๋า | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| hairtail_fish | ปลาดาบ | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| ham | แฮม | protein | product |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| holy_basil | ใบกะเพรา | herb |  |  |  | 1 | 0 | 0 | 0 | 0 | 1 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | pork_02 | _(none)_ |
| horseshoe_crab_roe | ไข่แมงดาทะเล | seafood | organ | other_seafood_family | other_seafood_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| imitation_crab | ปูอัด | seafood | product | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| instant_noodle | บะหมี่กึ่งสำเร็จรูป | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| jellyfish | แมงกะพรุน | seafood | species | other_seafood_family | other_seafood_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| kaffir_lime_leaf | ใบมะกรูด | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| kale | คะน้า | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| ketchup | ซอสมะเขือเทศ | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| knife_fish | ปลากราย | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| krill | กุ้งเคย | seafood | species | other_seafood_family | other_seafood_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| lemon_basil | ใบแมงลัก | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| lemongrass | ตะไคร้ | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| lime | มะนาว | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| lobster | กุ้งมังกร | seafood | species | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| mackerel | ปลาทู | seafood | species | sea_fish_family | fish_family | 7 | 0 | 6 | 0 | 0 | 13 | 0 | DIRECT_COVERAGE | 2 | 1 | 6 | 13 | 1 | 0 | fish_01, fish_02, fish_05, fish_06, fish_17 | _(none)_ |
| mantis_shrimp | กั้ง | seafood | species | other_seafood_family | other_seafood_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| margarine | มาการีน | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| mayonnaise | มายองเนส | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| meatball | ลูกชิ้น | protein | product |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| mekong_giant_catfish | ปลาบึก | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| milk | นมสด | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| minced_beef | เนื้อบด | protein | form | beef_family | beef_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| minced_chicken | ไก่สับ | protein | form | chicken_family | chicken_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| minced_pork | หมูสับ | protein | form | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| mixed_vegetables | ผักรวม | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| moo_yor | หมูยอ | protein | product | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| morning_glory | ผักบุ้ง | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| mud_crab | ปูทะเล | seafood | species | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| mushroom | เห็ด | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| needle_squid | หมึกกล้วย | seafood | species | squid_family | squid_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| octopus | หมึกสาย | seafood | species | squid_family | squid_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| olive_oil | น้ำมันมะกอก | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| onion | หอมหัวใหญ่ | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| oyster | หอยนางรม | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| oyster_sauce | น้ำมันหอย | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| palm_sugar | น้ำตาลปี๊บ | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pasta | พาสต้า | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| peeled_shrimp_meat | เนื้อกุ้งแกะ | seafood | form | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pepper | พริกไทย | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pla_kang | ปลาคัง | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pla_nuea_on | ปลาเนื้ออ่อน | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pla_samli | ปลาสำลี | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pomfret | ปลาจะละเม็ด | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork | หมู | protein | generic | pork_family | pork_family | 22 | 0 | 0 | 0 | 0 | 22 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | garlic_pork, pork_01, pork_02, pork_03, pork_04 | _(none)_ |
| pork_belly | หมูสามชั้น | protein | cut | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_blood | เลือดหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_cartilage | กระดูกอ่อนหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_ear | หูหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_fat | มันหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_heart | หัวใจหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_intestine | ไส้หมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_leg | ขาหมู | protein | cut | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_liver | ตับหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_loin | สันนอกหมู | protein | cut | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_neck | สันคอหมู | protein | cut | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_piece | หมูชิ้น | protein | form | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_ribs | ซี่โครงหมู | protein | cut | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_skin | หนังหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_stomach | กระเพาะหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_tenderloin | สันในหมู | protein | cut | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| pork_tongue | ลิ้นหมู | protein | organ | pork_family | pork_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| potato | มันฝรั่ง | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| quail_egg | ไข่นกกระทา | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| raw_rice | ข้าวสาร | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| razor_clam | หอยหลอด | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| red_curry_paste | พริกแกงแดง | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| red_tilapia | ปลาทับทิม | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| rice | ข้าวสวย | staple |  |  |  | 1 | 0 | 0 | 0 | 0 | 1 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | pork_fried_rice | _(none)_ |
| rice_bran_oil | น้ำมันรำข้าว | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| rice_flour | แป้งข้าวเจ้า | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| rice_noodle | เส้นก๋วยเตี๋ยว | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| rice_vermicelli | เส้นหมี่ | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| roe_crab | ปูไข่ | seafood | species | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| saba_mackerel | ปลาซาบะ | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| salmon | ปลาแซลมอน | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| salt | เกลือ | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| salted_egg | ไข่เค็ม | protein |  |  |  | 12 | 0 | 0 | 0 | 0 | 12 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | salted_egg_01, salted_egg_02, salted_egg_03, salted_egg_04, salted_egg_05 | _(none)_ |
| sausage | ไส้กรอก | protein | product |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| scallop | หอยเชลล์ | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| sea_bass | ปลากะพง | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 3 | 1 | 6 | 0 | 14 | 0 | _(none)_ | _(none)_ |
| sea_cucumber | ปลิงทะเล | seafood | species | other_seafood_family | other_seafood_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| sea_urchin | เม่นทะเล | seafood | species | other_seafood_family | other_seafood_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| seasoning_powder | ผงปรุงรส | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| seasoning_sauce | ซอสปรุงรส | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| seaweed | สาหร่าย | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| sesame_oil | น้ำมันงา | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| shallot | หอมแดง | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| shellfish | หอย | seafood | generic | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| shrimp | กุ้ง | seafood | generic | shrimp_family | shrimp_family | 20 | 0 | 0 | 0 | 0 | 20 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 | _(none)_ |
| shrimp_head | หัวกุ้ง | seafood | organ | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| shrimp_paste | กะปิ | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| shrimp_shell | เปลือกกุ้ง | seafood | organ | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| silver_barb | ปลาตะเพียน | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| snakehead | ปลาช่อน | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 2 | 1 | 4 | 0 | 27 | 0 | _(none)_ | _(none)_ |
| soft_shell_crab | ปูนิ่ม | seafood | product | crab_family | crab_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| sour_curry_paste | พริกแกงส้ม | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| soy_sauce | ซีอิ๊วขาว | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| spanish_mackerel | ปลาอินทรี | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| spotted_babylon | หอยหวาน | seafood | species | shellfish_family | shellfish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| spring_onion | ต้นหอม | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| squid | ปลาหมึก | seafood | generic | squid_family | squid_family | 20 | 0 | 0 | 0 | 0 | 20 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | squid_01, squid_02, squid_03, squid_04, squid_05 | _(none)_ |
| squid_roe | ไข่หมึก | seafood | organ | squid_family | squid_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| squid_tentacle | หนวดหมึก | seafood | organ | squid_family | squid_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| sticky_rice | ข้าวเหนียว | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| sugar | น้ำตาล | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| sweet_basil | โหระพา | herb |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| tamarind_sauce | น้ำมะขามเปียก | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| tapioca_starch | แป้งมัน | staple |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| tiger_shrimp | กุ้งลายเสือ | seafood | species | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| tilapia | ปลานิล | seafood | species | freshwater_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 2 | 1 | 5 | 0 | 14 | 0 | _(none)_ | _(none)_ |
| tofu | เต้าหู้ | protein |  |  |  | 1 | 0 | 0 | 0 | 0 | 1 | 0 | DIRECT_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | tofu_seaweed_soup | _(none)_ |
| tomato | มะเขือเทศ | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| tuna | ปลาทูน่า | seafood | species | sea_fish_family | fish_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| vinegar | น้ำส้มสายชู | seasoning |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| whiteleg_shrimp | กุ้งขาว | seafood | species | shrimp_family | shrimp_family | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| yardlong_bean | ถั่วฝักยาว | vegetable |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |
| yogurt | โยเกิร์ต | protein |  |  |  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | NO_COVERAGE | 0 | 0 | 0 | 0 | 0 | 27 | _(none)_ | _(none)_ |

## 6. DIRECT_COVERAGE

| canonicalId | displayName | category | taxonomyType | rootId | exact | preferred | compatible | substitute | family |
|---|---|---|---|---|---|---|---|---|---|
| beef | เนื้อวัว | protein | generic | beef_family | 20 | 0 | 0 | 0 | 0 |
| chicken | ไก่ | protein | generic | chicken_family | 21 | 0 | 0 | 0 | 0 |
| egg | ไข่ไก่ | protein |  |  | 21 | 0 | 0 | 0 | 0 |
| holy_basil | ใบกะเพรา | herb |  |  | 1 | 0 | 0 | 0 | 0 |
| mackerel | ปลาทู | seafood | species | fish_family | 7 | 0 | 6 | 0 | 0 |
| pork | หมู | protein | generic | pork_family | 22 | 0 | 0 | 0 | 0 |
| rice | ข้าวสวย | staple |  |  | 1 | 0 | 0 | 0 | 0 |
| salted_egg | ไข่เค็ม | protein |  |  | 12 | 0 | 0 | 0 | 0 |
| shrimp | กุ้ง | seafood | generic | shrimp_family | 20 | 0 | 0 | 0 | 0 |
| squid | ปลาหมึก | seafood | generic | squid_family | 20 | 0 | 0 | 0 | 0 |
| tofu | เต้าหู้ | protein |  |  | 1 | 0 | 0 | 0 | 0 |

## 7. ADAPTABLE_ONLY

_(none)_

## 8. NO_COVERAGE

| canonicalId | displayName | category | taxonomyType | rootId | exact | preferred | compatible | substitute | family |
|---|---|---|---|---|---|---|---|---|---|
| abalone | หอยเป๋าฮื้อ | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| apple_snail | หอยโข่ง | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| bacon | เบคอน | protein | product |  | 0 | 0 | 0 | 0 | 0 |
| banana_shrimp | กุ้งแชบ๊วย | seafood | species | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| beef_bone | กระดูกวัว | protein | organ | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_brisket | เนื้อหน้าอก | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_hanger_steak | เนื้อเสือร้องไห้ | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_intestine | ไส้วัว | protein | organ | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_liver | ตับวัว | protein | organ | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_oxtail | หางวัว | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_piece | เนื้อวัวชิ้น | protein | form | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_ribeye | ริบอาย | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_rump | เนื้อสะโพก | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_shank | เนื้อน่องลาย | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_short_rib | ซี่โครงวัว | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_sirloin | สันนอกวัว | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_spleen | ม้ามวัว | protein | organ | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_tbone | ทีโบน | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_tenderloin | สันในวัว | protein | cut | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_tendon | เอ็นวัว | protein | organ | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_tongue | ลิ้นวัว | protein | organ | beef_family | 0 | 0 | 0 | 0 | 0 |
| beef_tripe | ผ้าขี้ริ้ว | protein | organ | beef_family | 0 | 0 | 0 | 0 | 0 |
| bigfin_reef_squid | หมึกหอม | seafood | species | squid_family | 0 | 0 | 0 | 0 | 0 |
| blue_swimming_crab | ปูม้า | seafood | species | crab_family | 0 | 0 | 0 | 0 | 0 |
| bread | ขนมปัง | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| breadcrumbs | เกล็ดขนมปัง | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| broccoli | บรอกโคลี | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| brussels_sprout_shoot | แขนง | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| butter | เนยสด | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| cabbage | กะหล่ำปลี | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| canned_fish | ปลากระป๋อง | seafood | product |  | 0 | 0 | 0 | 0 | 0 |
| canned_tuna | ทูน่ากระป๋อง | seafood | product |  | 0 | 0 | 0 | 0 | 0 |
| carpet_clam | หอยลาย | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| carrot | แครอท | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| cashew | เม็ดมะม่วงหิมพานต์ | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| catfish | ปลาดุก | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| cauliflower | กะหล่ำดอก | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| celery | ขึ้นฉ่าย | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| century_egg | ไข่เยี่ยวม้า | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| cheese | ชีส | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| chicken_breast | อกไก่ | protein | cut | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_carcass | โครงไก่ | protein | organ | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_drumstick | น่องไก่ | protein | cut | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_feet | ขาไก่ | protein | organ | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_gizzard | กึ๋นไก่ | protein | organ | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_heart | หัวใจไก่ | protein | organ | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_liver | ตับไก่ | protein | organ | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_piece | เนื้อไก่ชิ้น | protein | form | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_skin | หนังไก่ | protein | organ | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_tenderloin | สันในไก่ | protein | cut | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_thigh | สะโพกไก่ | protein | cut | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_whole | ไก่ทั้งตัว | protein | whole | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chicken_wing | ปีกไก่ | protein | cut | chicken_family | 0 | 0 | 0 | 0 | 0 |
| chili | พริก | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| chili_paste | น้ำพริกเผา | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| chinese_cabbage | ผักกาดขาว | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| cockle | หอยแครง | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| coconut_milk | กะทิ | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| condensed_milk | นมข้นหวาน | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| cooking_oil | น้ำมันพืช | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| coriander | ผักชี | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| corn | ข้าวโพด | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| crab | ปู | seafood | generic | crab_family | 0 | 0 | 0 | 0 | 0 |
| crab_claw | กรรเชียงปู | seafood | organ | crab_family | 0 | 0 | 0 | 0 | 0 |
| crab_fat | มันปู | seafood | organ | crab_family | 0 | 0 | 0 | 0 | 0 |
| crab_meat | เนื้อปู | seafood | form | crab_family | 0 | 0 | 0 | 0 | 0 |
| cream | ครีม | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| crispy_flour | แป้งทอดกรอบ | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| cucumber | แตงกวา | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| cuttlefish | หมึกกระดอง | seafood | species | squid_family | 0 | 0 | 0 | 0 | 0 |
| dark_soy_sauce | ซีอิ๊วดำ | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| dried_chili | พริกแห้ง | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| dried_squid | หมึกแห้ง | seafood | product | squid_family | 0 | 0 | 0 | 0 | 0 |
| duck | เป็ด | protein | generic |  | 0 | 0 | 0 | 0 | 0 |
| duck_egg | ไข่เป็ด | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| edamame | ถั่วแระ | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| evaporated_milk | นมข้นจืด | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| fermented_soybean_paste | เต้าเจี้ยว | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| fish | ปลา | seafood | generic | fish_family | 0 | 0 | 0 | 0 | 0 |
| fish_belly | ท้องปลา | seafood | organ | fish_family | 0 | 0 | 0 | 0 | 0 |
| fish_bones | ก้างและกระดูกปลา | seafood | organ | fish_family | 0 | 0 | 0 | 0 | 0 |
| fish_fillet | เนื้อปลาแล่ | seafood | form | fish_family | 0 | 0 | 0 | 0 | 0 |
| fish_head | หัวปลา | seafood | organ | fish_family | 0 | 0 | 0 | 0 | 0 |
| fish_roe | ไข่ปลา | seafood | organ | fish_family | 0 | 0 | 0 | 0 | 0 |
| fish_sauce | น้ำปลา | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| fish_skin | หนังปลา | seafood | organ | fish_family | 0 | 0 | 0 | 0 | 0 |
| flour | แป้งสาลี | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| freshwater_eel | ปลาไหล | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| galangal | ข่า | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| garlic | กระเทียม | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| giant_river_prawn | กุ้งก้ามกราม | seafood | species | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| ginger | ขิง | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| glass_noodle | วุ้นเส้น | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| green_mussel | หอยแมลงภู่ | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| green_pea | ถั่วลันเตา | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| grouper | ปลาเก๋า | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| hairtail_fish | ปลาดาบ | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| ham | แฮม | protein | product |  | 0 | 0 | 0 | 0 | 0 |
| horseshoe_crab_roe | ไข่แมงดาทะเล | seafood | organ | other_seafood_family | 0 | 0 | 0 | 0 | 0 |
| imitation_crab | ปูอัด | seafood | product | crab_family | 0 | 0 | 0 | 0 | 0 |
| instant_noodle | บะหมี่กึ่งสำเร็จรูป | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| jellyfish | แมงกะพรุน | seafood | species | other_seafood_family | 0 | 0 | 0 | 0 | 0 |
| kaffir_lime_leaf | ใบมะกรูด | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| kale | คะน้า | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| ketchup | ซอสมะเขือเทศ | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| knife_fish | ปลากราย | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| krill | กุ้งเคย | seafood | species | other_seafood_family | 0 | 0 | 0 | 0 | 0 |
| lemon_basil | ใบแมงลัก | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| lemongrass | ตะไคร้ | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| lime | มะนาว | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| lobster | กุ้งมังกร | seafood | species | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| mantis_shrimp | กั้ง | seafood | species | other_seafood_family | 0 | 0 | 0 | 0 | 0 |
| margarine | มาการีน | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| mayonnaise | มายองเนส | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| meatball | ลูกชิ้น | protein | product |  | 0 | 0 | 0 | 0 | 0 |
| mekong_giant_catfish | ปลาบึก | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| milk | นมสด | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| minced_beef | เนื้อบด | protein | form | beef_family | 0 | 0 | 0 | 0 | 0 |
| minced_chicken | ไก่สับ | protein | form | chicken_family | 0 | 0 | 0 | 0 | 0 |
| minced_pork | หมูสับ | protein | form | pork_family | 0 | 0 | 0 | 0 | 0 |
| mixed_vegetables | ผักรวม | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| moo_yor | หมูยอ | protein | product | pork_family | 0 | 0 | 0 | 0 | 0 |
| morning_glory | ผักบุ้ง | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| mud_crab | ปูทะเล | seafood | species | crab_family | 0 | 0 | 0 | 0 | 0 |
| mushroom | เห็ด | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| needle_squid | หมึกกล้วย | seafood | species | squid_family | 0 | 0 | 0 | 0 | 0 |
| octopus | หมึกสาย | seafood | species | squid_family | 0 | 0 | 0 | 0 | 0 |
| olive_oil | น้ำมันมะกอก | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| onion | หอมหัวใหญ่ | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| oyster | หอยนางรม | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| oyster_sauce | น้ำมันหอย | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| palm_sugar | น้ำตาลปี๊บ | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| pasta | พาสต้า | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| peeled_shrimp_meat | เนื้อกุ้งแกะ | seafood | form | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| pepper | พริกไทย | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| pla_kang | ปลาคัง | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| pla_nuea_on | ปลาเนื้ออ่อน | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| pla_samli | ปลาสำลี | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| pomfret | ปลาจะละเม็ด | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| pork_belly | หมูสามชั้น | protein | cut | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_blood | เลือดหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_cartilage | กระดูกอ่อนหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_ear | หูหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_fat | มันหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_heart | หัวใจหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_intestine | ไส้หมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_leg | ขาหมู | protein | cut | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_liver | ตับหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_loin | สันนอกหมู | protein | cut | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_neck | สันคอหมู | protein | cut | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_piece | หมูชิ้น | protein | form | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_ribs | ซี่โครงหมู | protein | cut | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_skin | หนังหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_stomach | กระเพาะหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_tenderloin | สันในหมู | protein | cut | pork_family | 0 | 0 | 0 | 0 | 0 |
| pork_tongue | ลิ้นหมู | protein | organ | pork_family | 0 | 0 | 0 | 0 | 0 |
| potato | มันฝรั่ง | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| quail_egg | ไข่นกกระทา | protein |  |  | 0 | 0 | 0 | 0 | 0 |
| raw_rice | ข้าวสาร | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| razor_clam | หอยหลอด | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| red_curry_paste | พริกแกงแดง | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| red_tilapia | ปลาทับทิม | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| rice_bran_oil | น้ำมันรำข้าว | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| rice_flour | แป้งข้าวเจ้า | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| rice_noodle | เส้นก๋วยเตี๋ยว | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| rice_vermicelli | เส้นหมี่ | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| roe_crab | ปูไข่ | seafood | species | crab_family | 0 | 0 | 0 | 0 | 0 |
| saba_mackerel | ปลาซาบะ | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| salmon | ปลาแซลมอน | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| salt | เกลือ | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| sausage | ไส้กรอก | protein | product |  | 0 | 0 | 0 | 0 | 0 |
| scallop | หอยเชลล์ | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| sea_bass | ปลากะพง | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| sea_cucumber | ปลิงทะเล | seafood | species | other_seafood_family | 0 | 0 | 0 | 0 | 0 |
| sea_urchin | เม่นทะเล | seafood | species | other_seafood_family | 0 | 0 | 0 | 0 | 0 |
| seasoning_powder | ผงปรุงรส | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| seasoning_sauce | ซอสปรุงรส | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| seaweed | สาหร่าย | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| sesame_oil | น้ำมันงา | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| shallot | หอมแดง | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| shellfish | หอย | seafood | generic | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| shrimp_head | หัวกุ้ง | seafood | organ | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| shrimp_paste | กะปิ | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| shrimp_shell | เปลือกกุ้ง | seafood | organ | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| silver_barb | ปลาตะเพียน | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| snakehead | ปลาช่อน | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| soft_shell_crab | ปูนิ่ม | seafood | product | crab_family | 0 | 0 | 0 | 0 | 0 |
| sour_curry_paste | พริกแกงส้ม | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| soy_sauce | ซีอิ๊วขาว | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| spanish_mackerel | ปลาอินทรี | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| spotted_babylon | หอยหวาน | seafood | species | shellfish_family | 0 | 0 | 0 | 0 | 0 |
| spring_onion | ต้นหอม | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| squid_roe | ไข่หมึก | seafood | organ | squid_family | 0 | 0 | 0 | 0 | 0 |
| squid_tentacle | หนวดหมึก | seafood | organ | squid_family | 0 | 0 | 0 | 0 | 0 |
| sticky_rice | ข้าวเหนียว | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| sugar | น้ำตาล | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| sweet_basil | โหระพา | herb |  |  | 0 | 0 | 0 | 0 | 0 |
| tamarind_sauce | น้ำมะขามเปียก | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| tapioca_starch | แป้งมัน | staple |  |  | 0 | 0 | 0 | 0 | 0 |
| tiger_shrimp | กุ้งลายเสือ | seafood | species | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| tilapia | ปลานิล | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| tomato | มะเขือเทศ | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| tuna | ปลาทูน่า | seafood | species | fish_family | 0 | 0 | 0 | 0 | 0 |
| vinegar | น้ำส้มสายชู | seasoning |  |  | 0 | 0 | 0 | 0 | 0 |
| whiteleg_shrimp | กุ้งขาว | seafood | species | shrimp_family | 0 | 0 | 0 | 0 | 0 |
| yardlong_bean | ถั่วฝักยาว | vegetable |  |  | 0 | 0 | 0 | 0 | 0 |
| yogurt | โยเกิร์ต | protein |  |  | 0 | 0 | 0 | 0 | 0 |

## 9. Exclusion-reason breakdown for NO_COVERAGE ingredients

> Restricted to NO_COVERAGE rows (see section 3b for dataset-wide totals across every classification). `constraintMismatch(form/texture/method)` and `profileIncomplete(form/texture/method)` are computed from this ingredient's own `ingredientForms`/`textures`/`supportedCookingMethods` (shown in section 5) — a nonzero `profileIncomplete` value means the ingredient has no declared data on that dimension; it is a data-completeness gap, never evidence of a deliberate rejection. `unverifiedFamily`/`noMatch` never route into either split.

| canonicalId | displayName | explicitIdBlock | constraintMismatch(form/texture/method) | profileIncomplete(form/texture/method) | unverifiedFamily | noMatch |
|---|---|---|---|---|---|---|
| abalone | หอยเป๋าฮื้อ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| apple_snail | หอยโข่ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| bacon | เบคอน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| banana_shrimp | กุ้งแชบ๊วย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_bone | กระดูกวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_brisket | เนื้อหน้าอก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_hanger_steak | เนื้อเสือร้องไห้ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_intestine | ไส้วัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_liver | ตับวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_oxtail | หางวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_piece | เนื้อวัวชิ้น | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_ribeye | ริบอาย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_rump | เนื้อสะโพก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_shank | เนื้อน่องลาย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_short_rib | ซี่โครงวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_sirloin | สันนอกวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_spleen | ม้ามวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_tbone | ทีโบน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_tenderloin | สันในวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_tendon | เอ็นวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_tongue | ลิ้นวัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| beef_tripe | ผ้าขี้ริ้ว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| bigfin_reef_squid | หมึกหอม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| blue_swimming_crab | ปูม้า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| bread | ขนมปัง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| breadcrumbs | เกล็ดขนมปัง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| broccoli | บรอกโคลี | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| brussels_sprout_shoot | แขนง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| butter | เนยสด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cabbage | กะหล่ำปลี | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| canned_fish | ปลากระป๋อง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| canned_tuna | ทูน่ากระป๋อง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| carpet_clam | หอยลาย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| carrot | แครอท | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cashew | เม็ดมะม่วงหิมพานต์ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| catfish | ปลาดุก | 0 | 13/14/0 | 0/0/0 | 0 | 138 |
| cauliflower | กะหล่ำดอก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| celery | ขึ้นฉ่าย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| century_egg | ไข่เยี่ยวม้า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cheese | ชีส | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_breast | อกไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_carcass | โครงไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_drumstick | น่องไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_feet | ขาไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_gizzard | กึ๋นไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_heart | หัวใจไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_liver | ตับไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_piece | เนื้อไก่ชิ้น | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_skin | หนังไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_tenderloin | สันในไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_thigh | สะโพกไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_whole | ไก่ทั้งตัว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chicken_wing | ปีกไก่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chili | พริก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chili_paste | น้ำพริกเผา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| chinese_cabbage | ผักกาดขาว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cockle | หอยแครง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| coconut_milk | กะทิ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| condensed_milk | นมข้นหวาน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cooking_oil | น้ำมันพืช | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| coriander | ผักชี | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| corn | ข้าวโพด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| crab | ปู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| crab_claw | กรรเชียงปู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| crab_fat | มันปู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| crab_meat | เนื้อปู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cream | ครีม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| crispy_flour | แป้งทอดกรอบ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cucumber | แตงกวา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| cuttlefish | หมึกกระดอง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| dark_soy_sauce | ซีอิ๊วดำ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| dried_chili | พริกแห้ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| dried_squid | หมึกแห้ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| duck | เป็ด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| duck_egg | ไข่เป็ด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| edamame | ถั่วแระ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| evaporated_milk | นมข้นจืด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fermented_soybean_paste | เต้าเจี้ยว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fish | ปลา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fish_belly | ท้องปลา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fish_bones | ก้างและกระดูกปลา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fish_fillet | เนื้อปลาแล่ | 0 | 14/0/0 | 0/0/0 | 13 | 138 |
| fish_head | หัวปลา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fish_roe | ไข่ปลา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fish_sauce | น้ำปลา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| fish_skin | หนังปลา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| flour | แป้งสาลี | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| freshwater_eel | ปลาไหล | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| galangal | ข่า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| garlic | กระเทียม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| giant_river_prawn | กุ้งก้ามกราม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| ginger | ขิง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| glass_noodle | วุ้นเส้น | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| green_mussel | หอยแมลงภู่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| green_pea | ถั่วลันเตา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| grouper | ปลาเก๋า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| hairtail_fish | ปลาดาบ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| ham | แฮม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| horseshoe_crab_roe | ไข่แมงดาทะเล | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| imitation_crab | ปูอัด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| instant_noodle | บะหมี่กึ่งสำเร็จรูป | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| jellyfish | แมงกะพรุน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| kaffir_lime_leaf | ใบมะกรูด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| kale | คะน้า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| ketchup | ซอสมะเขือเทศ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| knife_fish | ปลากราย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| krill | กุ้งเคย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| lemon_basil | ใบแมงลัก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| lemongrass | ตะไคร้ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| lime | มะนาว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| lobster | กุ้งมังกร | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| mantis_shrimp | กั้ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| margarine | มาการีน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| mayonnaise | มายองเนส | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| meatball | ลูกชิ้น | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| mekong_giant_catfish | ปลาบึก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| milk | นมสด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| minced_beef | เนื้อบด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| minced_chicken | ไก่สับ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| minced_pork | หมูสับ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| mixed_vegetables | ผักรวม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| moo_yor | หมูยอ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| morning_glory | ผักบุ้ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| mud_crab | ปูทะเล | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| mushroom | เห็ด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| needle_squid | หมึกกล้วย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| octopus | หมึกสาย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| olive_oil | น้ำมันมะกอก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| onion | หอมหัวใหญ่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| oyster | หอยนางรม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| oyster_sauce | น้ำมันหอย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| palm_sugar | น้ำตาลปี๊บ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pasta | พาสต้า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| peeled_shrimp_meat | เนื้อกุ้งแกะ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pepper | พริกไทย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pla_kang | ปลาคัง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pla_nuea_on | ปลาเนื้ออ่อน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pla_samli | ปลาสำลี | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pomfret | ปลาจะละเม็ด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_belly | หมูสามชั้น | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_blood | เลือดหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_cartilage | กระดูกอ่อนหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_ear | หูหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_fat | มันหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_heart | หัวใจหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_intestine | ไส้หมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_leg | ขาหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_liver | ตับหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_loin | สันนอกหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_neck | สันคอหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_piece | หมูชิ้น | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_ribs | ซี่โครงหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_skin | หนังหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_stomach | กระเพาะหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_tenderloin | สันในหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| pork_tongue | ลิ้นหมู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| potato | มันฝรั่ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| quail_egg | ไข่นกกระทา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| raw_rice | ข้าวสาร | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| razor_clam | หอยหลอด | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| red_curry_paste | พริกแกงแดง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| red_tilapia | ปลาทับทิม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| rice_bran_oil | น้ำมันรำข้าว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| rice_flour | แป้งข้าวเจ้า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| rice_noodle | เส้นก๋วยเตี๋ยว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| rice_vermicelli | เส้นหมี่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| roe_crab | ปูไข่ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| saba_mackerel | ปลาซาบะ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| salmon | ปลาแซลมอน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| salt | เกลือ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sausage | ไส้กรอก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| scallop | หอยเชลล์ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sea_bass | ปลากะพง | 0 | 0/14/0 | 0/0/0 | 13 | 138 |
| sea_cucumber | ปลิงทะเล | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sea_urchin | เม่นทะเล | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| seasoning_powder | ผงปรุงรส | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| seasoning_sauce | ซอสปรุงรส | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| seaweed | สาหร่าย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sesame_oil | น้ำมันงา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| shallot | หอมแดง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| shellfish | หอย | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| shrimp_head | หัวกุ้ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| shrimp_paste | กะปิ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| shrimp_shell | เปลือกกุ้ง | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| silver_barb | ปลาตะเพียน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| snakehead | ปลาช่อน | 0 | 13/14/0 | 0/0/0 | 0 | 138 |
| soft_shell_crab | ปูนิ่ม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sour_curry_paste | พริกแกงส้ม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| soy_sauce | ซีอิ๊วขาว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| spanish_mackerel | ปลาอินทรี | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| spotted_babylon | หอยหวาน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| spring_onion | ต้นหอม | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| squid_roe | ไข่หมึก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| squid_tentacle | หนวดหมึก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sticky_rice | ข้าวเหนียว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sugar | น้ำตาล | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| sweet_basil | โหระพา | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| tamarind_sauce | น้ำมะขามเปียก | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| tapioca_starch | แป้งมัน | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| tiger_shrimp | กุ้งลายเสือ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| tilapia | ปลานิล | 0 | 0/14/0 | 0/0/0 | 13 | 138 |
| tomato | มะเขือเทศ | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| tuna | ปลาทูน่า | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| vinegar | น้ำส้มสายชู | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| whiteleg_shrimp | กุ้งขาว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| yardlong_bean | ถั่วฝักยาว | 0 | 0/0/0 | 27/0/0 | 0 | 138 |
| yogurt | โยเกิร์ต | 0 | 0/0/0 | 27/0/0 | 0 | 138 |

## 10. GENERIC_TO_SPECIFIC_ASYMMETRY

> Methodology note: this registry parents specific cuts/species/organs under a `*_family` navigation node as *siblings* of the generic ingredient (e.g. `pork` and `pork_piece` share `pork_family` as their parent) rather than nesting them under the generic. `relationship` below is `true_ancestor` only when `registry.ancestorIdsFor` actually returns a selectable ingredient with direct coverage; otherwise it is `generic_sibling` — the nearest generic-typed ingredient sharing the same immediate parent that has direct coverage. This is a factual observation, not a substitution claim.

| canonicalId | displayName | taxonomyType | parentId | rootId | nearestCounterpartId (relationship) | counterpartDirect(exact/preferred/compatible/substitute) | childDirect(exact/preferred/compatible/substitute) | childFamilyCount | sampleCounterpartRecipeIds |
|---|---|---|---|---|---|---|---|---|---|
| banana_shrimp | กุ้งแชบ๊วย | species | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |
| beef_bone | กระดูกวัว | organ | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_brisket | เนื้อหน้าอก | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_hanger_steak | เนื้อเสือร้องไห้ | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_intestine | ไส้วัว | organ | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_liver | ตับวัว | organ | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_oxtail | หางวัว | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_piece | เนื้อวัวชิ้น | form | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_ribeye | ริบอาย | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_rump | เนื้อสะโพก | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_shank | เนื้อน่องลาย | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_short_rib | ซี่โครงวัว | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_sirloin | สันนอกวัว | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_spleen | ม้ามวัว | organ | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_tbone | ทีโบน | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_tenderloin | สันในวัว | cut | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_tendon | เอ็นวัว | organ | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_tongue | ลิ้นวัว | organ | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| beef_tripe | ผ้าขี้ริ้ว | organ | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| bigfin_reef_squid | หมึกหอม | species | squid_family | squid_family | squid (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | squid_01, squid_02, squid_03, squid_04, squid_05 |
| chicken_breast | อกไก่ | cut | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_carcass | โครงไก่ | organ | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_drumstick | น่องไก่ | cut | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_feet | ขาไก่ | organ | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_gizzard | กึ๋นไก่ | organ | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_heart | หัวใจไก่ | organ | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_liver | ตับไก่ | organ | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_piece | เนื้อไก่ชิ้น | form | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_skin | หนังไก่ | organ | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_tenderloin | สันในไก่ | cut | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_thigh | สะโพกไก่ | cut | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_whole | ไก่ทั้งตัว | whole | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| chicken_wing | ปีกไก่ | cut | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| cuttlefish | หมึกกระดอง | species | squid_family | squid_family | squid (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | squid_01, squid_02, squid_03, squid_04, squid_05 |
| dried_squid | หมึกแห้ง | product | squid_family | squid_family | squid (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | squid_01, squid_02, squid_03, squid_04, squid_05 |
| giant_river_prawn | กุ้งก้ามกราม | species | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |
| lobster | กุ้งมังกร | species | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |
| minced_beef | เนื้อบด | form | beef_family | beef_family | beef (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | beef_01, beef_02, beef_03, beef_04, beef_05 |
| minced_chicken | ไก่สับ | form | chicken_family | chicken_family | chicken (generic_sibling) | 21/0/0/0 | 0/0/0/0 | 0 | chicken_01, chicken_02, chicken_03, chicken_04, chicken_05 |
| minced_pork | หมูสับ | form | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| moo_yor | หมูยอ | product | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| needle_squid | หมึกกล้วย | species | squid_family | squid_family | squid (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | squid_01, squid_02, squid_03, squid_04, squid_05 |
| octopus | หมึกสาย | species | squid_family | squid_family | squid (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | squid_01, squid_02, squid_03, squid_04, squid_05 |
| peeled_shrimp_meat | เนื้อกุ้งแกะ | form | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |
| pork_belly | หมูสามชั้น | cut | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_blood | เลือดหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_cartilage | กระดูกอ่อนหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_ear | หูหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_fat | มันหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_heart | หัวใจหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_intestine | ไส้หมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_leg | ขาหมู | cut | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_liver | ตับหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_loin | สันนอกหมู | cut | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_neck | สันคอหมู | cut | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_piece | หมูชิ้น | form | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_ribs | ซี่โครงหมู | cut | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_skin | หนังหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_stomach | กระเพาะหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_tenderloin | สันในหมู | cut | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| pork_tongue | ลิ้นหมู | organ | pork_family | pork_family | pork (generic_sibling) | 22/0/0/0 | 0/0/0/0 | 0 | garlic_pork, pork_01, pork_02, pork_03, pork_04 |
| shrimp_head | หัวกุ้ง | organ | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |
| shrimp_shell | เปลือกกุ้ง | organ | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |
| squid_roe | ไข่หมึก | organ | squid_family | squid_family | squid (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | squid_01, squid_02, squid_03, squid_04, squid_05 |
| squid_tentacle | หนวดหมึก | organ | squid_family | squid_family | squid (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | squid_01, squid_02, squid_03, squid_04, squid_05 |
| tiger_shrimp | กุ้งลายเสือ | species | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |
| whiteleg_shrimp | กุ้งขาว | species | shrimp_family | shrimp_family | shrimp (generic_sibling) | 20/0/0/0 | 0/0/0/0 | 0 | shrimp_01, shrimp_02, shrimp_03, shrimp_04, shrimp_05 |

## 11. Coverage grouped by root taxonomy / category / taxonomyType

### By root taxonomy

| Group | Total | DIRECT_COVERAGE | ADAPTABLE_ONLY | NO_COVERAGE | of which explicitIdBlock | of which constraintMismatch | of which profileIncomplete |
|---|---|---|---|---|---|---|---|
| _(none)_ | 94 | 5 | 0 | 89 | 0 | 0 | 94 |
| beef_family | 20 | 1 | 0 | 19 | 0 | 0 | 20 |
| chicken_family | 15 | 1 | 0 | 14 | 0 | 0 | 15 |
| crab_family | 9 | 0 | 0 | 9 | 0 | 0 | 9 |
| fish_family | 27 | 1 | 0 | 26 | 1 | 6 | 21 |
| other_seafood_family | 6 | 0 | 0 | 6 | 0 | 0 | 6 |
| pork_family | 20 | 1 | 0 | 19 | 0 | 0 | 20 |
| shellfish_family | 10 | 0 | 0 | 10 | 0 | 0 | 10 |
| shrimp_family | 9 | 1 | 0 | 8 | 0 | 0 | 9 |
| squid_family | 8 | 1 | 0 | 7 | 0 | 0 | 8 |

### By category

| Group | Total | DIRECT_COVERAGE | ADAPTABLE_ONLY | NO_COVERAGE | of which explicitIdBlock | of which constraintMismatch | of which profileIncomplete |
|---|---|---|---|---|---|---|---|
| herb | 15 | 1 | 0 | 14 | 0 | 0 | 15 |
| protein | 72 | 6 | 0 | 66 | 0 | 0 | 72 |
| seafood | 71 | 3 | 0 | 68 | 1 | 6 | 65 |
| seasoning | 26 | 0 | 0 | 26 | 0 | 0 | 26 |
| staple | 15 | 1 | 0 | 14 | 0 | 0 | 15 |
| vegetable | 19 | 0 | 0 | 19 | 0 | 0 | 19 |

### By taxonomy type

| Group | Total | DIRECT_COVERAGE | ADAPTABLE_ONLY | NO_COVERAGE | of which explicitIdBlock | of which constraintMismatch | of which profileIncomplete |
|---|---|---|---|---|---|---|---|
| _(none)_ | 87 | 5 | 0 | 82 | 0 | 0 | 87 |
| cut | 21 | 0 | 0 | 21 | 0 | 0 | 21 |
| form | 9 | 0 | 0 | 9 | 0 | 1 | 8 |
| generic | 9 | 5 | 0 | 4 | 0 | 0 | 9 |
| organ | 35 | 0 | 0 | 35 | 0 | 0 | 35 |
| product | 10 | 0 | 0 | 10 | 0 | 0 | 10 |
| species | 46 | 1 | 0 | 45 | 1 | 5 | 41 |
| whole | 1 | 0 | 0 | 1 | 0 | 0 | 1 |

## 12. Recipe metadata table

| recipeId | name | heroIngredientId | implicitExactIds | explicitExactIds | preferredIds | compatibleIds | substituteIds | familyIds | excludedIds | requiredForms/allowedForms/excludedForms | cookingMethods | suitabilityNotes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| beef_01 | เนื้อกระเทียมพริกไทย | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_02 | กะเพราเนื้อ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_03 | ข้าวผัดเนื้อใส่ไข่ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_04 | เนื้อผัดน้ำมันหอย | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_05 | เนื้อผัดพริกไทยดำ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_06 | เนื้อผัดขิง | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_07 | เนื้อผัดคะน้า | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_08 | เนื้อผัดบรอกโคลี | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_09 | เนื้อผัดพริกเผา | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_10 | เนื้อคั่วพริกเกลือ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | คั่ว | absent |
| beef_11 | เนื้อทอดกระเทียม | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| beef_12 | เนื้อทอดน้ำปลา | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| beef_13 | เนื้อทอดพริกไทย | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| beef_14 | เนื้อผัดไข่ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_15 | ต้มแซ่บเนื้อ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| beef_16 | แกงเผ็ดเนื้อ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | แกง | absent |
| beef_17 | เนื้อผัดเม็ดมะม่วง | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| beef_18 | เนื้ออบมันฝรั่ง | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | อบ | absent |
| beef_19 | ยำเนื้อย่าง | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| beef_20 | เนื้อย่างพริกไทยดำ | beef | beef | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ย่าง | absent |
| chicken_01 | ไก่กระเทียม | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_02 | กะเพราไก่ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_03 | ข้าวผัดไก่ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_04 | ไก่ผัดน้ำมันหอย | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_05 | ไก่ผัดพริกไทยดำ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_06 | ไก่ผัดขิง | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_07 | ไก่ผัดเม็ดมะม่วง | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_08 | ไก่ผัดบรอกโคลี | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_09 | ไก่ผัดพริกเผา | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_10 | ไก่คั่วพริกเกลือ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | คั่ว | absent |
| chicken_11 | ไก่ทอดกระเทียม | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| chicken_12 | ไก่ทอดน้ำปลา | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| chicken_13 | ไก่ทอดกรอบ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| chicken_14 | ไก่ผัดไข่ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| chicken_15 | ต้มข่าไก่เห็ด | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| chicken_16 | ต้มยำไก่ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| chicken_17 | แกงเผ็ดไก่ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | แกง | absent |
| chicken_18 | ไก่อบมันฝรั่ง | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | อบ | absent |
| chicken_19 | ยำไก่ฉีก | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| chicken_20 | ไก่ย่างพริกไทยดำ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ย่าง | absent |
| egg_01 | ไข่เจียวฟู | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| egg_02 | ไข่ดาว | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| egg_03 | ไข่คน | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| egg_04 | ไข่ตุ๋น | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | นึ่ง | absent |
| egg_05 | ไข่ลูกเขย | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| egg_06 | ไข่พะโล้ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| egg_07 | ไข่เจียวหมูสับ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| egg_08 | ไข่เจียวกุ้ง | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| egg_09 | ไข่เจียวเห็ด | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| egg_10 | ไข่ข้น | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| egg_11 | ข้าวไข่ข้น | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| egg_12 | ข้าวผัดไข่ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| egg_13 | กะเพราไข่ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| egg_14 | ยำไข่ดาว | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| egg_15 | ยำไข่ต้ม | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| egg_16 | ไข่ต้มทรงเครื่อง | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| egg_17 | ไข่น้ำ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| egg_18 | ไข่ผัดมะเขือเทศ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| egg_19 | ไข่ผัดหอมหัวใหญ่ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| egg_20 | แกงจืดไข่น้ำเต้าหู้ | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| fish_01 | ปลาทอดน้ำปลา | fish | fish | fish | _(none)_ | mackerel | _(none)_ | fish | _(none)_ | whole_cleaned / butterflied, whole_cleaned / _(none)_ | ทอด | present |
| fish_02 | ปลาทอดกระเทียม | fish | fish | fish | _(none)_ | mackerel | _(none)_ | fish | _(none)_ | whole_cleaned / butterflied, whole_cleaned / _(none)_ | ทอด | present |
| fish_03 | ปลานึ่งมะนาว | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | นึ่ง | present |
| fish_04 | ปลานึ่งซีอิ๊ว | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | นึ่ง | present |
| fish_05 | ปลาย่างเกลือ | fish | fish | fish | _(none)_ | mackerel | _(none)_ | fish | _(none)_ | whole_cleaned / butterflied, whole_cleaned / _(none)_ | ย่าง | present |
| fish_06 | ปลาย่างสมุนไพร | fish | fish | fish | _(none)_ | mackerel | _(none)_ | fish | _(none)_ | whole_cleaned / butterflied, whole_cleaned / _(none)_ | ย่าง | present |
| fish_07 | ต้มยำปลา | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ต้ม | present |
| fish_08 | ต้มข่าปลา | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ต้ม | present |
| fish_09 | แกงเผ็ดปลา | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | แกง | present |
| fish_10 | แกงส้มปลา | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | แกง | present |
| fish_11 | ปลาผัดขึ้นฉ่าย | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ผัด | present |
| fish_12 | ปลาผัดขิง | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ผัด | present |
| fish_13 | ปลาผัดพริกเผา | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ผัด | present |
| fish_14 | ปลาผัดพริกไทยดำ | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ผัด | present |
| fish_15 | ปลาคั่วพริกเกลือ | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | คั่ว | present |
| fish_16 | ยำปลา | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ยำ | present |
| fish_17 | ปลาราดพริก | fish | fish | fish | _(none)_ | mackerel | _(none)_ | fish | _(none)_ | whole_cleaned / butterflied, whole_cleaned / _(none)_ | ทอด | present |
| fish_18 | ปลาราดซอสมะขาม | fish | fish | fish | _(none)_ | mackerel | _(none)_ | fish | _(none)_ | whole_cleaned / butterflied, whole_cleaned / _(none)_ | ทอด | present |
| fish_19 | ปลาอบสมุนไพร | fish | fish | fish | _(none)_ | mackerel | _(none)_ | fish | _(none)_ | whole_cleaned / butterflied, whole_cleaned / _(none)_ | อบ | present |
| fish_20 | ข้าวผัดปลา | fish | fish | fish | _(none)_ | _(none)_ | _(none)_ | fish | mackerel | boneless_fillet / boneless_fillet, sliced_fillet / _(none)_ | ผัด | present |
| garlic_pork | หมูกระเทียม | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | _(none)_ | absent |
| mackerel_01 | เมี่ยงปลาทู | mackerel | mackerel | mackerel | mackerel | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / butterflied, whole_cleaned / _(none)_ | นึ่ง | present |
| mackerel_02 | น้ำพริกปลาทู | mackerel | mackerel | mackerel | mackerel | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / butterflied, whole_cleaned / _(none)_ | ทอด | present |
| mackerel_03 | ต้มยำปลาทู | mackerel | mackerel | mackerel | mackerel | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / butterflied, whole_cleaned / _(none)_ | ต้ม | present |
| mackerel_04 | ปลาทูทอด | mackerel | mackerel | mackerel | mackerel | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / butterflied, whole_cleaned / _(none)_ | ทอด | present |
| mackerel_05 | ยำปลาทู | mackerel | mackerel | mackerel | mackerel | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / butterflied, whole_cleaned / _(none)_ | ยำ | present |
| mackerel_06 | ฉู่ฉี่ปลาทู | mackerel | mackerel | mackerel | mackerel | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / butterflied, whole_cleaned / _(none)_ | แกง | present |
| mackerel_07 | ข้าวคลุกน้ำพริกปลาทู | mackerel | mackerel | mackerel | mackerel | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / butterflied, whole_cleaned / _(none)_ | คลุก | present |
| pork_01 | หมูกระเทียมพริกไทย | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_02 | กะเพราหมู | pork | holy_basil, pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_03 | ข้าวผัดหมูใส่ไข่ | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_04 | หมูผัดน้ำมันหอย | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_05 | หมูผัดพริกไทยดำ | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_06 | หมูผัดขิง | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_07 | หมูผัดคะน้า | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_08 | หมูผัดบรอกโคลี | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_09 | หมูผัดพริกเผา | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_10 | หมูคั่วพริกเกลือ | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | คั่ว | absent |
| pork_11 | หมูทอดกระเทียม | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| pork_12 | หมูทอดน้ำปลา | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| pork_13 | หมูทอดพริกไทย | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| pork_14 | หมูผัดไข่ | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_15 | ต้มจืดเต้าหู้หมูสับ | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| pork_16 | แกงจืดกะหล่ำปลีหมู | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| pork_17 | หมูผัดเม็ดมะม่วง | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| pork_18 | หมูอบมันฝรั่ง | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | อบ | absent |
| pork_19 | ยำหมูย่าง | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| pork_20 | หมูย่างพริกไทยดำ | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ย่าง | absent |
| pork_basil | กะเพราหมูสับ | pork | pork | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | _(none)_ | absent |
| pork_fried_rice | ข้าวผัดหมู | rice | rice | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | _(none)_ | absent |
| salted_egg_01 | ยำไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| salted_egg_02 | ข้าวผัดไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_03 | หมูสับผัดไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_04 | กุ้งผัดไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_05 | ไข่เค็มผัดพริกเผา | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_06 | ไข่เค็มผัดต้นหอม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_07 | ไข่เค็มผัดขิง | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_08 | ไข่เค็มผัดเห็ด | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_09 | เต้าหู้ผัดไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_10 | คะน้าผัดไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_11 | บรอกโคลีผัดไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| salted_egg_12 | หมูสับนึ่งไข่เค็ม | salted_egg | salted_egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | นึ่ง | absent |
| shrimp_01 | กุ้งผัดกระเทียม | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_02 | ข้าวผัดกุ้ง | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_03 | กะเพรากุ้ง | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_04 | ต้มยำกุ้ง | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| shrimp_05 | กุ้งผัดพริกเผา | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_06 | กุ้งคั่วพริกเกลือ | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | คั่ว | absent |
| shrimp_07 | กุ้งผัดไข่เค็ม | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_08 | กุ้งผัดบรอกโคลี | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_09 | กุ้งผัดผักรวม | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_10 | กุ้งผัดน้ำมันหอย | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_11 | กุ้งผัดพริกไทยดำ | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_12 | กุ้งทอดกระเทียม | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| shrimp_13 | กุ้งทอดซอสมะขาม | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| shrimp_14 | กุ้งอบวุ้นเส้น | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | อบ | absent |
| shrimp_15 | กุ้งนึ่งมะนาว | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | นึ่ง | absent |
| shrimp_16 | ยำกุ้ง | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| shrimp_17 | ไข่เจียวกุ้ง | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| shrimp_18 | กุ้งผัดข้าวโพดอ่อน | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_19 | กุ้งผัดถั่วลันเตา | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| shrimp_20 | แกงส้มกุ้ง | shrimp | shrimp | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | แกง | absent |
| squid_01 | ปลาหมึกผัดกระเทียม | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_02 | กะเพราปลาหมึก | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_03 | ปลาหมึกผัดไข่เค็ม | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_04 | ปลาหมึกผัดพริกเผา | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_05 | ปลาหมึกผัดน้ำมันหอย | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_06 | ปลาหมึกผัดพริกไทยดำ | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_07 | ปลาหมึกคั่วพริกเกลือ | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | คั่ว | absent |
| squid_08 | ปลาหมึกทอดกระเทียม | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| squid_09 | ปลาหมึกทอดน้ำปลา | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| squid_10 | ปลาหมึกนึ่งมะนาว | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | นึ่ง | absent |
| squid_11 | ยำปลาหมึก | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ยำ | absent |
| squid_12 | ต้มยำปลาหมึก | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ต้ม | absent |
| squid_13 | ปลาหมึกผัดผักรวม | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_14 | ปลาหมึกผัดคะน้า | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_15 | ปลาหมึกผัดขึ้นฉ่าย | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_16 | ข้าวผัดปลาหมึก | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ผัด | absent |
| squid_17 | ไข่เจียวปลาหมึก | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ทอด | absent |
| squid_18 | ปลาหมึกย่าง | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | ย่าง | absent |
| squid_19 | ปลาหมึกอบวุ้นเส้น | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | อบ | absent |
| squid_20 | แกงเผ็ดปลาหมึก | squid | squid | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | แกง | absent |
| thai_omelette | ไข่เจียว | egg | egg | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | _(none)_ | absent |
| tofu_seaweed_soup | ซุปเต้าหู้สาหร่ายใส่ไข่ | tofu | tofu | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | _(none)_ | absent |
| tom_kha_gai | ต้มข่าไก่ | chicken | chicken | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ | _(none)_ / _(none)_ / _(none)_ | _(none)_ | absent |

## 13. Suggested review queue

| Priority | canonicalId / recipeId | Summary |
|---|---|---|
| P0_INVALID_REFERENCE | fish_01 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_02 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_03 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_04 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_05 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_06 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_07 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_08 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_09 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_10 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_11 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_12 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_13 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_14 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_15 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_16 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_17 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_18 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_19 | invalid_family_reference in ingredientFamilyIds="fish" |
| P0_INVALID_REFERENCE | fish_20 | invalid_family_reference in ingredientFamilyIds="fish" |
| P1_CONFLICTING_METADATA | mackerel_01 | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| P1_CONFLICTING_METADATA | mackerel_02 | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| P1_CONFLICTING_METADATA | mackerel_03 | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| P1_CONFLICTING_METADATA | mackerel_04 | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| P1_CONFLICTING_METADATA | mackerel_05 | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| P1_CONFLICTING_METADATA | mackerel_06 | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| P1_CONFLICTING_METADATA | mackerel_07 | Id appears in more than one eligibility/exclusion field: exactIngredientIds, preferredIngredientIds. |
| P2_CONSTRAINT_MISMATCH_REVIEW | catfish | catfish has 27 recipe(s) whose required form/texture/cooking-method genuinely conflicts with its declared profile — verify the conflict is correct, not an authoring error on either side. |
| P2_CONSTRAINT_MISMATCH_REVIEW | fish_fillet | fish_fillet has 14 recipe(s) whose required form/texture/cooking-method genuinely conflicts with its declared profile — verify the conflict is correct, not an authoring error on either side. |
| P2_CONSTRAINT_MISMATCH_REVIEW | sea_bass | sea_bass has 14 recipe(s) whose required form/texture/cooking-method genuinely conflicts with its declared profile — verify the conflict is correct, not an authoring error on either side. |
| P2_CONSTRAINT_MISMATCH_REVIEW | snakehead | snakehead has 27 recipe(s) whose required form/texture/cooking-method genuinely conflicts with its declared profile — verify the conflict is correct, not an authoring error on either side. |
| P2_CONSTRAINT_MISMATCH_REVIEW | tilapia | tilapia has 14 recipe(s) whose required form/texture/cooking-method genuinely conflicts with its declared profile — verify the conflict is correct, not an authoring error on either side. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | banana_shrimp | banana_shrimp has no direct coverage while shrimp (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_bone | beef_bone has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_brisket | beef_brisket has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_hanger_steak | beef_hanger_steak has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_intestine | beef_intestine has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_liver | beef_liver has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_oxtail | beef_oxtail has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_piece | beef_piece has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_ribeye | beef_ribeye has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_rump | beef_rump has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_shank | beef_shank has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_short_rib | beef_short_rib has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_sirloin | beef_sirloin has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_spleen | beef_spleen has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_tbone | beef_tbone has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_tenderloin | beef_tenderloin has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_tendon | beef_tendon has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_tongue | beef_tongue has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | beef_tripe | beef_tripe has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | bigfin_reef_squid | bigfin_reef_squid has no direct coverage while squid (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_breast | chicken_breast has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_carcass | chicken_carcass has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_drumstick | chicken_drumstick has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_feet | chicken_feet has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_gizzard | chicken_gizzard has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_heart | chicken_heart has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_liver | chicken_liver has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_piece | chicken_piece has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_skin | chicken_skin has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_tenderloin | chicken_tenderloin has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_thigh | chicken_thigh has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_whole | chicken_whole has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | chicken_wing | chicken_wing has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | cuttlefish | cuttlefish has no direct coverage while squid (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | dried_squid | dried_squid has no direct coverage while squid (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | giant_river_prawn | giant_river_prawn has no direct coverage while shrimp (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | lobster | lobster has no direct coverage while shrimp (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | minced_beef | minced_beef has no direct coverage while beef (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | minced_chicken | minced_chicken has no direct coverage while chicken (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | minced_pork | minced_pork has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | moo_yor | moo_yor has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | needle_squid | needle_squid has no direct coverage while squid (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | octopus | octopus has no direct coverage while squid (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | peeled_shrimp_meat | peeled_shrimp_meat has no direct coverage while shrimp (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_belly | pork_belly has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_blood | pork_blood has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_cartilage | pork_cartilage has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_ear | pork_ear has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_fat | pork_fat has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_heart | pork_heart has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_intestine | pork_intestine has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_leg | pork_leg has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_liver | pork_liver has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_loin | pork_loin has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_neck | pork_neck has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_piece | pork_piece has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_ribs | pork_ribs has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_skin | pork_skin has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_stomach | pork_stomach has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_tenderloin | pork_tenderloin has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | pork_tongue | pork_tongue has no direct coverage while pork (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | shrimp_head | shrimp_head has no direct coverage while shrimp (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | shrimp_shell | shrimp_shell has no direct coverage while shrimp (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | squid_roe | squid_roe has no direct coverage while squid (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | squid_tentacle | squid_tentacle has no direct coverage while squid (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | tiger_shrimp | tiger_shrimp has no direct coverage while shrimp (generic_sibling) does. |
| P2_GENERIC_SPECIFIC_ASYMMETRY | whiteleg_shrimp | whiteleg_shrimp has no direct coverage while shrimp (generic_sibling) does. |
| P2_PROFILE_COMPLETENESS | abalone | abalone lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | apple_snail | apple_snail lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | bacon | bacon lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | banana_shrimp | banana_shrimp lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_bone | beef_bone lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_brisket | beef_brisket lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_hanger_steak | beef_hanger_steak lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_intestine | beef_intestine lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_liver | beef_liver lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_oxtail | beef_oxtail lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_piece | beef_piece lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_ribeye | beef_ribeye lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_rump | beef_rump lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_shank | beef_shank lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_short_rib | beef_short_rib lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_sirloin | beef_sirloin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_spleen | beef_spleen lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_tbone | beef_tbone lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_tenderloin | beef_tenderloin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_tendon | beef_tendon lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_tongue | beef_tongue lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | beef_tripe | beef_tripe lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | bigfin_reef_squid | bigfin_reef_squid lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | blue_swimming_crab | blue_swimming_crab lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | bread | bread lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | breadcrumbs | breadcrumbs lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | broccoli | broccoli lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | brussels_sprout_shoot | brussels_sprout_shoot lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | butter | butter lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cabbage | cabbage lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | canned_fish | canned_fish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | canned_tuna | canned_tuna lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | carpet_clam | carpet_clam lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | carrot | carrot lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cashew | cashew lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cauliflower | cauliflower lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | celery | celery lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | century_egg | century_egg lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cheese | cheese lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_breast | chicken_breast lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_carcass | chicken_carcass lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_drumstick | chicken_drumstick lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_feet | chicken_feet lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_gizzard | chicken_gizzard lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_heart | chicken_heart lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_liver | chicken_liver lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_piece | chicken_piece lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_skin | chicken_skin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_tenderloin | chicken_tenderloin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_thigh | chicken_thigh lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_whole | chicken_whole lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chicken_wing | chicken_wing lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chili | chili lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chili_paste | chili_paste lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | chinese_cabbage | chinese_cabbage lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cockle | cockle lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | coconut_milk | coconut_milk lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | condensed_milk | condensed_milk lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cooking_oil | cooking_oil lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | coriander | coriander lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | corn | corn lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | crab | crab lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | crab_claw | crab_claw lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | crab_fat | crab_fat lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | crab_meat | crab_meat lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cream | cream lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | crispy_flour | crispy_flour lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cucumber | cucumber lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | cuttlefish | cuttlefish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | dark_soy_sauce | dark_soy_sauce lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | dried_chili | dried_chili lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | dried_squid | dried_squid lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | duck | duck lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | duck_egg | duck_egg lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | edamame | edamame lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | evaporated_milk | evaporated_milk lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fermented_soybean_paste | fermented_soybean_paste lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fish | fish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fish_belly | fish_belly lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fish_bones | fish_bones lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fish_head | fish_head lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fish_roe | fish_roe lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fish_sauce | fish_sauce lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | fish_skin | fish_skin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | flour | flour lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | freshwater_eel | freshwater_eel lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | galangal | galangal lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | garlic | garlic lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | giant_river_prawn | giant_river_prawn lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | ginger | ginger lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | glass_noodle | glass_noodle lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | green_mussel | green_mussel lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | green_pea | green_pea lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | grouper | grouper lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | hairtail_fish | hairtail_fish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | ham | ham lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | horseshoe_crab_roe | horseshoe_crab_roe lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | imitation_crab | imitation_crab lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | instant_noodle | instant_noodle lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | jellyfish | jellyfish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | kaffir_lime_leaf | kaffir_lime_leaf lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | kale | kale lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | ketchup | ketchup lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | knife_fish | knife_fish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | krill | krill lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | lemon_basil | lemon_basil lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | lemongrass | lemongrass lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | lime | lime lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | lobster | lobster lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | mantis_shrimp | mantis_shrimp lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | margarine | margarine lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | mayonnaise | mayonnaise lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | meatball | meatball lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | mekong_giant_catfish | mekong_giant_catfish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | milk | milk lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | minced_beef | minced_beef lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | minced_chicken | minced_chicken lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | minced_pork | minced_pork lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | mixed_vegetables | mixed_vegetables lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | moo_yor | moo_yor lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | morning_glory | morning_glory lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | mud_crab | mud_crab lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | mushroom | mushroom lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | needle_squid | needle_squid lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | octopus | octopus lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | olive_oil | olive_oil lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | onion | onion lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | oyster | oyster lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | oyster_sauce | oyster_sauce lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | palm_sugar | palm_sugar lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pasta | pasta lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | peeled_shrimp_meat | peeled_shrimp_meat lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pepper | pepper lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pla_kang | pla_kang lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pla_nuea_on | pla_nuea_on lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pla_samli | pla_samli lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pomfret | pomfret lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_belly | pork_belly lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_blood | pork_blood lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_cartilage | pork_cartilage lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_ear | pork_ear lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_fat | pork_fat lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_heart | pork_heart lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_intestine | pork_intestine lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_leg | pork_leg lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_liver | pork_liver lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_loin | pork_loin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_neck | pork_neck lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_piece | pork_piece lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_ribs | pork_ribs lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_skin | pork_skin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_stomach | pork_stomach lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_tenderloin | pork_tenderloin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | pork_tongue | pork_tongue lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | potato | potato lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | quail_egg | quail_egg lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | raw_rice | raw_rice lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | razor_clam | razor_clam lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | red_curry_paste | red_curry_paste lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | red_tilapia | red_tilapia lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | rice_bran_oil | rice_bran_oil lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | rice_flour | rice_flour lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | rice_noodle | rice_noodle lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | rice_vermicelli | rice_vermicelli lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | roe_crab | roe_crab lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | saba_mackerel | saba_mackerel lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | salmon | salmon lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | salt | salt lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sausage | sausage lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | scallop | scallop lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sea_cucumber | sea_cucumber lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sea_urchin | sea_urchin lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | seasoning_powder | seasoning_powder lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | seasoning_sauce | seasoning_sauce lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | seaweed | seaweed lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sesame_oil | sesame_oil lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | shallot | shallot lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | shellfish | shellfish lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | shrimp_head | shrimp_head lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | shrimp_paste | shrimp_paste lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | shrimp_shell | shrimp_shell lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | silver_barb | silver_barb lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | soft_shell_crab | soft_shell_crab lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sour_curry_paste | sour_curry_paste lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | soy_sauce | soy_sauce lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | spanish_mackerel | spanish_mackerel lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | spotted_babylon | spotted_babylon lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | spring_onion | spring_onion lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | squid_roe | squid_roe lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | squid_tentacle | squid_tentacle lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sticky_rice | sticky_rice lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sugar | sugar lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | sweet_basil | sweet_basil lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | tamarind_sauce | tamarind_sauce lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | tapioca_starch | tapioca_starch lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | tiger_shrimp | tiger_shrimp lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | tomato | tomato lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | tuna | tuna lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | vinegar | vinegar lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | whiteleg_shrimp | whiteleg_shrimp lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | yardlong_bean | yardlong_bean lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P2_PROFILE_COMPLETENESS | yogurt | yogurt lacks profile data (ingredientForms/textures/supportedCookingMethods) needed for confident compatibility evaluation on 27 recipe(s) — a data-completeness gap, not evidence of a deliberate rejection. |
| P4_ZERO_COVERAGE_CONTENT_DECISION | abalone | abalone classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | apple_snail | apple_snail classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | bacon | bacon classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | banana_shrimp | banana_shrimp classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_bone | beef_bone classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_brisket | beef_brisket classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_hanger_steak | beef_hanger_steak classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_intestine | beef_intestine classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_liver | beef_liver classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_oxtail | beef_oxtail classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_piece | beef_piece classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_ribeye | beef_ribeye classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_rump | beef_rump classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_shank | beef_shank classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_short_rib | beef_short_rib classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_sirloin | beef_sirloin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_spleen | beef_spleen classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_tbone | beef_tbone classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_tenderloin | beef_tenderloin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_tendon | beef_tendon classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_tongue | beef_tongue classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | beef_tripe | beef_tripe classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | bigfin_reef_squid | bigfin_reef_squid classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | blue_swimming_crab | blue_swimming_crab classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | bread | bread classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | breadcrumbs | breadcrumbs classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | broccoli | broccoli classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | brussels_sprout_shoot | brussels_sprout_shoot classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | butter | butter classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cabbage | cabbage classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | canned_fish | canned_fish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | canned_tuna | canned_tuna classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | carpet_clam | carpet_clam classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | carrot | carrot classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cashew | cashew classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | catfish | catfish classification=NO_COVERAGE (constraint mismatch). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cauliflower | cauliflower classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | celery | celery classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | century_egg | century_egg classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cheese | cheese classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_breast | chicken_breast classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_carcass | chicken_carcass classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_drumstick | chicken_drumstick classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_feet | chicken_feet classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_gizzard | chicken_gizzard classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_heart | chicken_heart classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_liver | chicken_liver classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_piece | chicken_piece classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_skin | chicken_skin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_tenderloin | chicken_tenderloin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_thigh | chicken_thigh classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_whole | chicken_whole classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chicken_wing | chicken_wing classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chili | chili classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chili_paste | chili_paste classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | chinese_cabbage | chinese_cabbage classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cockle | cockle classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | coconut_milk | coconut_milk classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | condensed_milk | condensed_milk classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cooking_oil | cooking_oil classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | coriander | coriander classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | corn | corn classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | crab | crab classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | crab_claw | crab_claw classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | crab_fat | crab_fat classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | crab_meat | crab_meat classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cream | cream classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | crispy_flour | crispy_flour classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cucumber | cucumber classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | cuttlefish | cuttlefish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | dark_soy_sauce | dark_soy_sauce classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | dried_chili | dried_chili classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | dried_squid | dried_squid classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | duck | duck classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | duck_egg | duck_egg classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | edamame | edamame classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | evaporated_milk | evaporated_milk classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fermented_soybean_paste | fermented_soybean_paste classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish | fish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish_belly | fish_belly classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish_bones | fish_bones classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish_fillet | fish_fillet classification=NO_COVERAGE (constraint mismatch). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish_head | fish_head classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish_roe | fish_roe classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish_sauce | fish_sauce classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | fish_skin | fish_skin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | flour | flour classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | freshwater_eel | freshwater_eel classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | galangal | galangal classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | garlic | garlic classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | giant_river_prawn | giant_river_prawn classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | ginger | ginger classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | glass_noodle | glass_noodle classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | green_mussel | green_mussel classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | green_pea | green_pea classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | grouper | grouper classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | hairtail_fish | hairtail_fish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | ham | ham classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | horseshoe_crab_roe | horseshoe_crab_roe classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | imitation_crab | imitation_crab classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | instant_noodle | instant_noodle classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | jellyfish | jellyfish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | kaffir_lime_leaf | kaffir_lime_leaf classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | kale | kale classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | ketchup | ketchup classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | knife_fish | knife_fish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | krill | krill classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | lemon_basil | lemon_basil classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | lemongrass | lemongrass classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | lime | lime classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | lobster | lobster classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | mantis_shrimp | mantis_shrimp classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | margarine | margarine classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | mayonnaise | mayonnaise classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | meatball | meatball classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | mekong_giant_catfish | mekong_giant_catfish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | milk | milk classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | minced_beef | minced_beef classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | minced_chicken | minced_chicken classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | minced_pork | minced_pork classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | mixed_vegetables | mixed_vegetables classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | moo_yor | moo_yor classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | morning_glory | morning_glory classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | mud_crab | mud_crab classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | mushroom | mushroom classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | needle_squid | needle_squid classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | octopus | octopus classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | olive_oil | olive_oil classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | onion | onion classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | oyster | oyster classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | oyster_sauce | oyster_sauce classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | palm_sugar | palm_sugar classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pasta | pasta classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | peeled_shrimp_meat | peeled_shrimp_meat classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pepper | pepper classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pla_kang | pla_kang classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pla_nuea_on | pla_nuea_on classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pla_samli | pla_samli classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pomfret | pomfret classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_belly | pork_belly classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_blood | pork_blood classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_cartilage | pork_cartilage classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_ear | pork_ear classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_fat | pork_fat classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_heart | pork_heart classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_intestine | pork_intestine classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_leg | pork_leg classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_liver | pork_liver classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_loin | pork_loin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_neck | pork_neck classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_piece | pork_piece classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_ribs | pork_ribs classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_skin | pork_skin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_stomach | pork_stomach classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_tenderloin | pork_tenderloin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | pork_tongue | pork_tongue classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | potato | potato classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | quail_egg | quail_egg classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | raw_rice | raw_rice classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | razor_clam | razor_clam classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | red_curry_paste | red_curry_paste classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | red_tilapia | red_tilapia classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | rice_bran_oil | rice_bran_oil classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | rice_flour | rice_flour classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | rice_noodle | rice_noodle classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | rice_vermicelli | rice_vermicelli classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | roe_crab | roe_crab classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | saba_mackerel | saba_mackerel classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | salmon | salmon classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | salt | salt classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sausage | sausage classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | scallop | scallop classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sea_bass | sea_bass classification=NO_COVERAGE (constraint mismatch). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sea_cucumber | sea_cucumber classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sea_urchin | sea_urchin classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | seasoning_powder | seasoning_powder classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | seasoning_sauce | seasoning_sauce classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | seaweed | seaweed classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sesame_oil | sesame_oil classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | shallot | shallot classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | shellfish | shellfish classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | shrimp_head | shrimp_head classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | shrimp_paste | shrimp_paste classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | shrimp_shell | shrimp_shell classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | silver_barb | silver_barb classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | snakehead | snakehead classification=NO_COVERAGE (constraint mismatch). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | soft_shell_crab | soft_shell_crab classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sour_curry_paste | sour_curry_paste classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | soy_sauce | soy_sauce classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | spanish_mackerel | spanish_mackerel classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | spotted_babylon | spotted_babylon classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | spring_onion | spring_onion classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | squid_roe | squid_roe classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | squid_tentacle | squid_tentacle classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sticky_rice | sticky_rice classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sugar | sugar classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | sweet_basil | sweet_basil classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | tamarind_sauce | tamarind_sauce classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | tapioca_starch | tapioca_starch classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | tiger_shrimp | tiger_shrimp classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | tilapia | tilapia classification=NO_COVERAGE (constraint mismatch). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | tomato | tomato classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | tuna | tuna classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | vinegar | vinegar classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | whiteleg_shrimp | whiteleg_shrimp classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | yardlong_bean | yardlong_bean classification=NO_COVERAGE (profile incomplete). |
| P4_ZERO_COVERAGE_CONTENT_DECISION | yogurt | yogurt classification=NO_COVERAGE (profile incomplete). |

## 14. Explicit non-conclusions

- No compatibility metadata was added.
- No recipes were invented.
- No taxonomy relationship (parent/family/ancestor/generic-sibling) was treated as a substitution.
- Zero coverage does not automatically mean a defect.
- Family coverage does not automatically mean a specific cut/species is culinarily suitable — production keeps family-tier matches in a separate adaptable pool for exactly this reason.
- An `unverifiedFamily` result does not imply the ingredient lacks authored recipe coverage that it should have — it only means the recipes it was checked against declared support for other families, not this one. It is a diagnostic count, not a coverage tier, and it never demotes an ingredient into a different classification.
- `noMatch` (a recipe simply never mentions the ingredient) is expected to be the largest exclusion count for almost every ingredient and carries no implication on its own.
- EXPLICIT_ID_BLOCK is always a deliberate, ingredient-specific authored rejection (an id literally on a recipe's excludedIngredientIds) — worth a look, but still not a claim that the exclusion is wrong.
- CONSTRAINT_MISMATCH means the ingredient DOES have declared profile data that genuinely conflicts with a recipe's stated constraint — worth verifying the conflict itself is correctly authored on either side, not that the ingredient was "blocked."
- PROFILE_INCOMPLETE is explicitly NOT evidence of a deliberate rejection. It means the canonical ingredient has no declared data on the dimension a recipe required, so production's strict "no data means no match" default excluded the pair. The correction here is content work (author the missing ingredientForms/textures/supportedCookingMethods), not a decision to reverse — nothing was ever decided about this ingredient specifically.
- Product review is required before any metadata write.

