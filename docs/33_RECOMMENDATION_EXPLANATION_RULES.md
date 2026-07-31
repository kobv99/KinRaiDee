# Recommendation Explanation Rules

Every `RecipeRecommendation` carries:

- Recommendation Score and per-factor point breakdown;
- Recipe Match %;
- available and missing ingredient counts;
- available substitution mapping;
- Pantry completion;
- Pantry utilization;
- expiring ingredient IDs;
- generated reasons;
- generated badges;
- informational shopping preview.

A badge is emitted only from configuration and evaluated data. The UI may
translate or style an enum but must never independently decide whether a badge
applies. “Why Not?” compares the same breakdown between ranked Recipes; no
separate hidden ranking logic is allowed.

Normal user surfaces present Recipe Match, readiness labels, reasons, and
badges. The weighted Recommendation Score and per-factor point breakdown are
developer diagnostics and are visible only in Recommendation QA.
