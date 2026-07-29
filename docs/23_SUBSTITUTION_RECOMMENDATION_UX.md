# Substitution Recommendation UX

## Product principle

> The application recommends. The user decides.

Ingredient substitutions are advisory. A recommendation must never interrupt
recipe browsing, prevent Start Cooking, or require acceptance before the user
continues.

## Presentation states

The Recipe detail screen presents substitution recommendations in three states:

1. **Collapsed** — the default state. A compact card shows the recommendation
   count and an Expand affordance without taking over the Recipe screen.
2. **Expanded** — the user explicitly opens the bounded, scrollable list and may
   accept an available substitute, leave it for later, or hide it.
3. **Hidden** — the card becomes a small reopen chip and the Recipe content
   immediately receives the released space.

No state leaves empty placeholder spacing.

## Interaction rules

- Accept is optional and records only the user's explicit choice.
- Ignore or `ไว้ทีหลัง` collapses the card.
- Hide reduces the recommendation to a reopen chip.
- Reopen restores the expanded card.
- Recipe browsing and Start Cooking remain available in every state.
- Viewing, ignoring, collapsing, hiding, or reopening never mutates Pantry,
  Shopping, or Recipe data.

## Recommendation-change behavior

Panel preference is stored per Recipe together with a deterministic
recommendation signature. The signature includes the original ingredient,
ordered substitute IDs, Pantry availability, compatibility score, and
explanation.

A hidden or collapsed preference remains stable across Riverpod rebuilds and
navigation while the signature is unchanged. When the recommendation signature
changes, the panel returns to the compact collapsed state so the user can notice
the new advice without being interrupted by a full card.

## Layout constraints

- The expanded card is bounded to roughly one-third of the viewport and scrolls
  internally.
- The Recipe's primary workflow remains in the screen's `Expanded` content area.
- The compact and hidden states restore the full available Recipe area.
- Narrow screens, large text, and multiple substitutes must not overflow.

## Acceptance checks

1. Open a Recipe with at least two valid substitutes.
2. Confirm the panel initially appears collapsed.
3. Expand it and continue scrolling the Recipe.
4. Select `ไว้ทีหลัง`; confirm the panel collapses and Start Cooking remains
   available.
5. Hide the panel; confirm only the small reopen chip remains and no blank gap is
   left.
6. Navigate away and return; confirm the hidden state remains for the same
   recommendation set.
7. Change Pantry so ranking or availability changes; confirm the panel returns
   to collapsed.
8. Reopen and accept a Pantry-available substitute; confirm acceptance is
   recorded, while ignoring every other recommendation remains possible.
