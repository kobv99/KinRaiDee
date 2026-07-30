# Sprint 4 Release Notes – Ingredient Substitution Knowledge Base

## Added

- Versioned JSON Ingredient Substitution Knowledge Base.
- Cached Knowledge Base loader and replaceable repository boundary.
- Deterministic compatibility calculation and multi-substitute ranking.
- Pantry-first ordering and explainable recommendation evidence.
- Canonical recipe coverage for Rice, Mackerel, and Sea Bass.
- Additional substitution data for Soy Sauce, Butter, and Garlic.
- Thai Pantry Essentials for Salmon, Shallot, Coriander, and Palm Sugar.
- Species-specific Tilapia and Salmon Recipes with explicit ingredient roles
  and complete instructions.
- Explicit per-Recipe `supportsSubstitutions` capability.
- Collapsed, expanded, and hidden substitution recommendation states.
- A compact reopen chip after the user hides a recommendation.
- Widget regression coverage for Ignore, Hide, Reopen, recommendation changes,
  optional Accept, and uninterrupted Start Cooking.
- Data-driven Ingredient Hierarchy with separate root, category, family, and
  selectable ingredient nodes.
- Canonical pork, chicken, beef, and duck cuts for hierarchical Pantry
  selection.
- Structured Recipe step model supporting titles, ingredient references,
  quantities, duration, heat, completion cues, and tips.
- Ingredient, Recipe, Knowledge Base, Substitution, and cross-system
  architecture guidelines.

## Improved

- Architecture supports future substitution metadata without changing business
  logic.
- Recommendation generation remains deterministic across navigation and state
  refreshes.
- Canonical fish species remain distinct for Recipe matching while categories
  are reserved for organization.
- Fried Rice treats Rice as a Primary Ingredient and ranks by readiness.
- Pantry Search is the first content control on the Pantry page.
- Substitution visibility now follows a documented three-condition rule.
- Recipe substitution content uses a bounded responsive scrolling region.
- The recommendation panel now starts compact and releases Recipe screen space
  when collapsed or hidden.
- Hidden and collapsed state persists while the deterministic recommendation
  signature remains unchanged.
- A materially changed recommendation returns as a compact collapsed card
  instead of forcing the full panel open.
- Ingredient selection now uses progressive disclosure and full-hierarchy
  search with localized breadcrumb paths.
- Generic meat and fish choices are explicit selectable leaves; their family
  nodes are navigation-only.
- Browse and Search now use independent interaction paths; Search selection
  proceeds directly to Quantity without opening the tree.
- Legacy Recipe packs now produce method-aware multi-step workflows instead of
  a fixed three-step sequence, while authored Recipes may define any valid
  number of structured steps.

## Fixed

- No substitution facts are hardcoded in service or UI logic.
- Accepted substitutions no longer cause recommendation cards to disappear.
- Substitution cards display localized Thai ingredient names instead of
  canonical English IDs.
- Generic Fish no longer satisfies Mackerel, Tilapia, Salmon, or Sea Bass.
- Recommendation cards no longer push Pantry Search down the page.
- Accept Substitute now confirms the selection, updates Recipe Readiness, and
  displays the accepted state.
- Added direct canonical Recipe mappings instead of treating fish species as
  generic Fish.
- Closed canonical alias and Recipe participation gaps identified by the
  Knowledge Base completeness audit.
- Substitution recommendations no longer permanently occupy a large section of
  Recipe detail.
- Ignore, Hide, and Reopen no longer gate Recipe browsing or Start Cooking.
- Hiding the panel no longer leaves empty layout spacing.
- Expanding or collapsing a category no longer changes ingredient selection,
  and selecting one leaf no longer affects its siblings.
- Cooking progress now derives from the actual Recipe step count.

## Known Limitations

- Initial Knowledge Base covers a focused set of canonical Thai ingredients.
- Newly separated meat cuts currently improve Pantry identity and hierarchy;
  additional cut-specific Recipes remain a future Knowledge Base expansion.
- Product Acceptance remains pending Product Owner manual testing.

## Out of Scope

- AI and LLM
- Meal Planning
- Nutrition and budget calculations
- Food Waste Optimization
- Voice Assistant
- Automatic Ingredient Replacement
