# Recipe Scoring Rules

Default factors:

| Factor | Weight | Meaning |
|---|---:|---|
| Recipe Match | 0.55 | Quantity-aware readiness from actual Pantry matching |
| Few Missing | 0.15 | Required ingredient completeness |
| Expiring Ingredients | 0.12 | Matched Pantry items expiring within 3 days |
| Quick Meal | 0.08 | Cooking time relative to 30-minute target |
| Low Complexity | 0.05 | Ingredient count relative to 12-item threshold |
| Favourite | 0.03 | Explicit favourite Recipe input |
| Not Recently Cooked | 0.02 | Diversity against the 7-day history window |

`Recommendation Score = Σ(normalized factor × factor weight / total weight)`.

Recipe Match % remains the readiness score and is not replaced by the broader
Recommendation Score. Unknown cooking time receives a neutral quick-meal value.
