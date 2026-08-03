import 'package:flutter/material.dart';

import '../../domain/images/image_fallback_resolver.dart';
import '../../domain/ingredients/canonical_ingredient.dart';
import '../components/resolved_image.dart';
import '../design_tokens/app_radius.dart';

/// Renders a canonical ingredient's photo when an approved
/// [CanonicalIngredient.image] is available, always degrading gracefully to
/// [CanonicalIngredient.emoji] — never a broken image icon, and never
/// fabricated imagery.
///
/// Always takes a resolved [CanonicalIngredient], never a raw display name,
/// alias, or ID — callers must resolve through
/// `CanonicalIngredientRegistry` first, so an image can never be
/// constructed from user-facing text.
class IngredientImage extends StatelessWidget {
  const IngredientImage({
    required this.ingredient,
    super.key,
    this.size = 56,
    this.borderRadius = AppRadius.largeRadius,
  });

  final CanonicalIngredient ingredient;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolution = resolveImageCandidates(
      metadata: ingredient.image,
      fallbackGlyph: ingredient.emoji,
    );
    return ResolvedImage(
      resolution: resolution,
      semanticLabel: 'รูปภาพวัตถุดิบ ${ingredient.displayName()}',
      size: size,
      borderRadius: borderRadius,
      loadedKey: ValueKey<String>('ingredient-image-${ingredient.id}'),
      exhaustedFallbackKey: ValueKey<String>(
        'ingredient-image-fallback-${ingredient.id}',
      ),
    );
  }
}
