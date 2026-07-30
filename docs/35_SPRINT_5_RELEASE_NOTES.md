# Sprint 5 Release Notes – Smart Recipe Recommendation Engine

## Added

- Configurable multi-factor Recipe Recommendation Engine.
- Explainable score breakdown and deterministic ranking.
- Recipe Match, Pantry completion, Pantry utilization, badges, filters, sorts,
  expiring-ingredient influence, and informational shopping preview.
- Recommendation explanation panel in Recipe Detail.

## Improved

- Recommendation ranking is centralized in the domain layer.
- Pantry is indexed by canonical ingredient ID for efficient evaluation.
- Stable Recipe ID tie-breaking prevents ranking changes across rebuilds.

## Fixed

- Recommendation percentages and badges no longer require presentation-layer
  assumptions.

## Known Limitations

- Favourite Recipe input is architecturally supported but the product has no
  Recipe favourite persistence control yet.
- Available substitution mapping remains supplied by the substitution boundary.
- “Why Not?” data is available through comparable score breakdowns; a dedicated
  comparison screen is not included.

## Out of Scope

- AI, LLM, and machine learning
- Nutrition and price data sources
- Popularity and user rating services
- Automatic Shopping List mutation
