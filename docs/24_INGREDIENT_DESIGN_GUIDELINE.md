# Ingredient Design Guideline

## Source of truth

`thai_ingredients.json` is the canonical source for ingredients that Pantry,
Recipes, Shopping, and Substitution may store or reference.
`ingredient_hierarchy.json` contains navigation nodes and placement rules only.
UI widgets must not define another ingredient catalog.

## Identity rules

- A canonical ID represents one real, purchasable ingredient.
- Category and family nodes are navigation-only and never canonical IDs.
- A family and a selectable ingredient must never share a record.
- An unspecified cut is an explicit leaf, labelled in Thai as
  `หมู (ไม่ระบุส่วน)`, `ไก่ (ไม่ระบุส่วน)`, `เนื้อวัว (ไม่ระบุส่วน)`, or
  `ปลา (ไม่ระบุชนิด)`.
- Aliases resolve spelling and language variants; they must not collapse
  different species or cuts.
- Renamed IDs require an explicit redirect and migration coverage.

## Hierarchy rules

The supported levels are root → category → family → ingredient. Only an
ingredient node is selectable. Expansion changes visibility only. Selection
changes the chosen canonical leaf only. Categories support browsing and never
participate in Recipe matching.

## Granularity

Sibling families use comparable granularity. If Pork exposes cuts, Chicken and
Beef must also expose their common cuts. Seafood uses Fish as a family and fish
species as leaves. Shrimp and Squid may be direct leaves until their own
families contain multiple meaningful varieties.

## Localization

Canonical names may be English internally. Every selectable production
ingredient requires a Thai display name and useful Thai aliases. UI obtains
names from the canonical registry, never from IDs.

## Browse and Search

Browse and Search are independent modes:

- Browse progressively reveals immediate children.
- Search hides the tree and searches every selectable leaf.
- Selecting a Search result immediately exits selection and opens Quantity.
- Search never expands or mutates the browse tree.

