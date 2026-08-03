# Image Foundation

## Purpose

A shared, deterministic model for presentation imagery — location,
provenance, editorial approval — plus one resolver and one runtime widget
that every image-bearing entity uses. This branch ships the foundation
only: the domain model, the resolver, and two reusable widgets. No product
screen renders a real photo as a result of this work; `RecipeCard`,
`RecipeDetailHeader`, `CookingStepCard`, `top_picks_section.dart`, and
`cooking_wizard_page.dart` are unchanged.

## Ownership

`ImageMetadata` (`lib/core/domain/images/image_metadata.dart`) is owned by
exactly two places:

- `Recipe`, via a computed `imageMetadata` getter adapted from the legacy
  `imageUrl` field (see Legacy Compatibility below).
- `CanonicalIngredient`, via an optional `image` field.

Ingredient family and category nodes do **not** have a separate image
concept. `CanonicalIngredient` already represents ingredient, family, and
category records as one class distinguished by `nodeType`, so `image`
support on `CanonicalIngredient` covers all three for free — there is
exactly one place ingredient image ownership lives.

UI must never construct an image path from a display name, alias, or raw
ID. `IngredientImage` enforces this structurally: it takes a resolved
`CanonicalIngredient`, never a `String`. Callers resolve aliases through
`CanonicalIngredientRegistry` first; the resolved record's own `image`
field is what renders, never something reconstructed from the lookup key.

## Source Precedence

`ImageMetadata` may carry a local `assetPath`, a remote `remoteUrl`, or
both at once. The approved precedence is:

1. local asset;
2. remote URL;
3. deterministic fallback glyph.

`locationType` (`asset` / `network` / `none`) declares the record's primary
intent and is validated against which fields are populated — it does not
itself decide candidate order, which is always asset-before-network,
structurally, in `resolveImageCandidates`
(`lib/core/domain/images/image_fallback_resolver.dart`).

`ImageProvenance` (`unknown` / `aiGenerated` / `photographed` /
`licensedStock` / `firstParty`) is fully independent of location — where
an image is stored says nothing about who made it.

## Fallback Policy

One resolver, `resolveImageCandidates`, serves recipes, canonical
ingredients, and (by extension) family/category nodes. It is pure domain
logic: it returns an ordered candidate chain and a fallback glyph, and has
no way to know whether an asset is actually missing or a network request
actually fails.

`ResolvedImage` (`lib/core/design_system/components/resolved_image.dart`)
is the single place that runtime failure is handled: it tries the first
candidate, advances to the next on any load error, and renders the
fallback glyph once the chain is empty or exhausted. `RecipeImage` and
`IngredientImage` both delegate to it — neither widget re-implements
fallback selection.

**Only `ImageReviewStatus.approved` metadata may ever produce a
renderable candidate.** `unreviewed` and `rejected` both resolve to zero
candidates, i.e. the fallback glyph, regardless of what paths are
populated. This is enforced once, in the resolver — not duplicated in any
widget. A future preview/admin surface may relax this for reviewers; that
is explicitly out of scope here.

## Legacy Compatibility (`Recipe.imageUrl`)

`Recipe.imageUrl`, its type, and its JSON parsing are unchanged by this
branch. `Recipe.imageMetadata` is a computed adapter, not a stored field:

- absent/blank `imageUrl` → `ImageMetadata(locationType: none)`;
- populated `imageUrl` → `ImageMetadata(locationType: network, remoteUrl:
  imageUrl, reviewStatus: approved)`.

The `approved` status here is deliberate: before this branch, a populated
`imageUrl` was already rendered unconditionally (no review concept
existed). Marking the adapted value pre-approved is what preserves that
existing behavior under the foundation's new approved-only rendering
policy, rather than silently hiding every existing recipe photo behind an
unreviewed gate.

Hero and thumbnail roles both resolve from this same single adapted value
today, since `Recipe` has only one image field. A future `thumbnailUrl`
(or similar) would only require updating the adapter, not the resolver or
either widget.

## Licensing / Source Metadata

`ImageMetadata.attribution` is an optional free-text field for crediting a
source (photographer, stock library, etc.). It is not validated for
correctness or completeness — only that, if present, it is non-blank.
`ImageProvenance` records the origin category (`photographed`,
`licensedStock`, `aiGenerated`, `firstParty`, `unknown`) so a future
licensing audit can filter by it without re-deriving provenance from
context.

## Future Offline/Cache Strategy

No caching layer exists yet (`Image.network`/`Image.asset` are used
directly, with no `cached_network_image` or similar dependency). This is
deliberate — out of scope for this branch per the approved scope (no CDN,
no cache manager, no large image library). A future iteration should
introduce caching at the `ResolvedImage` level only, so `RecipeImage` and
`IngredientImage` inherit it without change.

## Cooking-Step Visuals — Future Extension

`Recipe.steps` is a plain `List<String>`; there is no per-step entity or
data shape a visual type could attach to today. Adding a
`CookingStepVisualType`-style enum in this branch, with nothing to carry
it, would be speculative dead code — deliberately not done here.

A future branch wiring step visuals needs, at minimum:

- a typed `RecipeStep` entity (or a backward-compatible adapter mirroring
  the `Recipe.imageMetadata` pattern above) to replace or wrap the plain
  `String`, since a visual type has nowhere to live on a bare string;
- the visual type itself to be optional and data-driven — most steps will
  never carry one, and existing recipes with only `List<String>` steps
  must keep parsing and rendering exactly as they do today;
- reuse of the same `resolveImageCandidates`/`ResolvedImage` pair if the
  visual is ever a real image, or a distinct, much smaller resolver if
  it's only ever an illustrative icon set (no `IconData` belongs in the
  domain layer — see `ImageMetadata`'s deliberate absence of a
  `fallbackType`/icon concept, kept to a single glyph representation for
  the same reason).

## Production Contribution Rules

- Every `ImageMetadata` a content pipeline produces must set
  `reviewStatus` explicitly; the default (`unreviewed`) is intentional and
  will not render in production.
- `assetPath` and `remoteUrl` may coexist (asset preferred, remote as
  fallback) — do not treat their coexistence as an error.
- Do not add real image binaries to `assets/` as part of foundation work;
  none exist yet, and none are required by any test in this branch (tests
  that need image bytes use an in-memory fake `AssetBundle`, never a file
  checked into the repository).
