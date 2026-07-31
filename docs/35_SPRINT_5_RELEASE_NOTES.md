# Sprint 5 Release Notes – Smart Recipe Recommendation Engine

## Added

- Configurable multi-factor Recipe Recommendation Engine.
- Explainable score breakdown and deterministic ranking.
- Recipe Match, Pantry completion, Pantry utilization, badges, filters, sorts,
  expiring-ingredient influence, and informational shopping preview.
- Recommendation explanation panel in Recipe Detail.
- Canonical Ingredient tracking and lifecycle metadata.
- Recommendation Dashboard, Knowledge Base Health, Debug View, Why Not, and
  reusable QA Pantry Profiles.
- Compact substitution launcher and popup.

## Improved

- Recommendation ranking is centralized in the domain layer.
- Pantry is indexed by canonical ingredient ID for efficient evaluation.
- Stable Recipe ID tie-breaking prevents ranking changes across rebuilds.
- Availability-first matching prevents false missing ingredients caused by
  household unit differences.
- Almost-ready Recipes remain visible when only a small number of required
  ingredients are missing.
- The Recipe catalog is search-first and uses lazy, limited result rendering
  instead of building the entire Knowledge Base at once.
- Recommendation Dashboard summaries now apply their corresponding domain
  filters and visibly identify the active selection.
- Normal user surfaces use Pantry Match and readiness labels; internal weighted
  scores remain in Recommendation QA.
- The Pantry recommendation banner is compact by default and reveals guidance
  and Shopping actions only when requested.
- The Recipe page presents a single recommendation hierarchy: header,
  Recommendation Dashboard, one Top Recommendation List, then Search.
- Recommendation refresh belongs to the recommendation list header and uses a
  lightweight text button instead of a large action at the bottom of the page.
- Cooking Mode is now a dedicated full-screen workflow: Recipe summary,
  ingredient checklist, one cooking step at a time, then a completion screen.
- Cooking Mode shows `ขั้นตอน X / N`, a progress bar, and the estimated
  remaining time, and supports Previous, Next, and a confirmed exit.
- Starting Cooking Mode creates a Cooking Session that stores the Recipe,
  serving count, and start time, ready for cooking history and statistics.

## Fixed

- Recommendation percentages and badges no longer require presentation-layer
  assumptions.
- Chicken Breast remains a real canonical leaf instead of redirecting to the
  generic Chicken parent.
- Expanded recommendation explanations no longer overflow short viewports.
- Static Recommendation Dashboard summaries now work as primary filter actions.
- Internal Recommendation Score values no longer leak into normal Recipe cards
  or explanation panels.
- The duplicated “More Recipes from Main Ingredient” section and the duplicated
  match-threshold chips no longer compete with the primary recommendation list.
- Recipe Detail no longer doubles as the cooking screen, so planning and
  cooking assistance never share the same surface.

## Known Limitations

- Favourite Recipe input is architecturally supported but the product has no
  Recipe favourite persistence control yet.
- Available substitution mapping remains supplied by the substitution boundary.
- Recipe catalog searches display at most 30 results per query.
- “Why Not?” data is available through comparable score breakdowns; a dedicated
  comparison screen is not included.

## Out of Scope

- AI, LLM, and machine learning
- Nutrition and price data sources
- Popularity and user rating services
- Automatic Shopping List mutation
