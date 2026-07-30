# Recipe Design Guideline

## Ingredient references

Recipes reference canonical selectable leaves only. A Recipe must not reference
a root, category, or family node. Ingredient roles and weights are explicit:
Primary controls candidate discovery, Secondary affects readiness, and
Optional never blocks cooking.

## Authoring standard

Recipe instructions are ordered structured steps. Each step supports:

- `title`
- `instruction`
- `ingredientIds`
- `quantities`
- `durationMinutes`
- `heatLevel`
- `completionCue`
- optional `tip`

Simple Recipes normally contain 3–5 steps, normal Recipes 6–10, and complex
Recipes more than 10. Step count follows the cooking process and is never padded
or truncated to a fixed template.

Instructions describe observable actions and completion cues. Avoid
`เตรียมวัตถุดิบ`, `ปรุงให้สุก`, or `ปรุงรส` as standalone instructions without
specific preparation, heat, duration, or observable completion information.

## Cooking progress

Progress is derived from `recipe.instructions.length`. UI renders
`ขั้นตอน N จาก M` using the actual Recipe. No screen may hardcode a total step
count.

## Compatibility

Legacy string steps remain readable during migration. New and edited
production Recipes must use structured step objects. Validation reports legacy
steps so they can be migrated rather than silently losing metadata.

