# Recommendation Ranking Algorithm

Supported deterministic orders:

- Best Match
- Highest Score
- Fastest
- Least Missing Ingredients
- Most Pantry Ingredients Used
- Newest Recipe version

The chosen sort key is compared first, Recommendation Score second, and stable
Recipe ID last. Identical inputs therefore always produce identical results.

Filters execute before sorting and support Recipe Match, cooking time,
difficulty, cuisine, main ingredient, meal type, missing count, Pantry Friendly,
and Healthy.
