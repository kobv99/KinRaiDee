# Sprint 4 Release Notes – Ingredient Substitution Knowledge Base

## Added

- Versioned JSON Ingredient Substitution Knowledge Base.
- Cached Knowledge Base loader and replaceable repository boundary.
- Deterministic compatibility calculation and multi-substitute ranking.
- Pantry-first ordering and explainable recommendation evidence.
- Canonical recipe coverage for Rice, Mackerel, and Sea Bass.
- Additional substitution data for Soy Sauce, Butter, and Garlic.
- Explicit per-Recipe `supportsSubstitutions` capability.

## Improved

- Architecture supports future substitution metadata without changing business
  logic.
- Recommendation generation remains deterministic across navigation and state
  refreshes.
- Canonical fish species remain distinct for Recipe matching while categories
  are reserved for organization.
- Fried Rice treats Rice as a Primary Ingredient and ranks by readiness.
- Pantry Search is the first content control on the Pantry page.
- Substitution visibility now follows a documented three-condition rule.
- Recipe substitution content uses a bounded responsive scrolling region.

## Fixed

- No substitution facts are hardcoded in service or UI logic.
- Accepted substitutions no longer cause recommendation cards to disappear.
- Substitution cards display localized Thai ingredient names instead of
  canonical English IDs.
- Generic Fish no longer satisfies Mackerel, Tilapia, Salmon, or Sea Bass.
- Recommendation cards no longer push Pantry Search down the page.
- Accept Substitute now confirms the selection, updates Recipe Readiness, and
  displays the accepted state.
- Added direct canonical Recipe mappings instead of treating fish species as
  generic Fish.

## Known Limitations

- Initial Knowledge Base covers a focused set of canonical Thai ingredients.
- Product Acceptance remains pending Product Owner manual testing.

## Out of Scope

- AI and LLM
- Meal Planning
- Nutrition and budget calculations
- Food Waste Optimization
- Voice Assistant
- Automatic Ingredient Replacement
