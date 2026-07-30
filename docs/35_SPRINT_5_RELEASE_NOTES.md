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

## Fixed

- Recommendation percentages and badges no longer require presentation-layer
  assumptions.
- Chicken Breast remains a real canonical leaf instead of redirecting to the
  generic Chicken parent.
- Expanded recommendation explanations no longer overflow short viewports.
- Static Recommendation Dashboard summaries now work as primary filter actions.
- Internal Recommendation Score values no longer leak into normal Recipe cards
  or explanation panels.

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
