# Recommendation Engine Design

Sprint 5 uses a deterministic domain engine. Widgets render
`RecipeRecommendation` and never calculate score, badges, filters, or ranking.

Flow:

`Pantry + RecipeMatch + Cooking History + Configuration`
→ `RecipeRecommendationEngine`
→ immutable score breakdown, reasons, badges, completion, utilization, and
shopping preview
→ provider
→ UI.

Each factor is normalized to 0–1 and contributes weighted points. New factors
can be appended without changing UI contracts. Evaluation indexes Pantry by
canonical ID once, then evaluates recipes linearly. Final ties use Recipe ID.

Future nutrition, cost, preference, popularity, rating, and AI signals must
enter through typed factor inputs and configuration. AI must not bypass the
deterministic explanation contract.

Pantry readiness is availability-first. Canonical tracking metadata decides
whether quantity is Presence, Count, Weight, or Stock based. Candidate
visibility allows almost-ready Recipes with only a small number of missing
required ingredients; removing one ingredient must not erase the decision
option.

The internal QA surface contains Knowledge Base Health, reusable Pantry
Profiles, per-factor Debug View, and Why Not comparisons.
