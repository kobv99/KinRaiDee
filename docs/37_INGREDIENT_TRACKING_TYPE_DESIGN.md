# Ingredient Tracking Type Design

## Presence Only

For herbs and produce where household quantities are rarely precise.
Availability is canonical identity plus positive, unexpired stock. Unit
differences do not reduce Recipe Match.

## Count Based

For eggs, onions, potatoes, and naturally counted items. Compatible counts are
used when possible. If legacy units cannot convert, identity availability is a
safe fallback and must not incorrectly mark the ingredient missing.

## Weight Based

For meat, fish, and seafood. Gram/kilogram quantities improve readiness. Legacy
incompatible units fall back to identity availability rather than a false
missing result.

## Stock Based

For sauces, oil, salt, sugar, and seasonings. Recommendation checks Available,
Low, or Out of Stock; it does not compare tablespoon requirements against a
bottle’s exact volume.

Tracking type is Canonical Ingredient metadata. Widgets must not infer it.
