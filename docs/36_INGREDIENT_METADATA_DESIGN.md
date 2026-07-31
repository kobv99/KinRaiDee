# Ingredient Metadata Design

Every Canonical Ingredient supports:

- stable ID, canonical/localized names, aliases, and category;
- tracking type;
- default purchase, inventory, preferred, and recommended units;
- perishable flag and typical shelf life;
- substitution capability;
- default and recommended storage.

This metadata belongs to the canonical data layer. Recommendation, Pantry,
Shopping, expiration, and future AI consumers read the same contract instead
of maintaining ingredient-name conditions.

`chicken_breast` is a selectable canonical leaf under `chicken`; it must never
redirect to its parent. Parent compatibility may support discovery, while
Recipe matching retains the real ingredient identity.
