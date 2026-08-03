import 'package:flutter/material.dart';

import '../../../../core/design_system/components/resolved_image.dart';
import '../../../../core/design_system/design_tokens/app_radius.dart';
import '../../../../core/domain/images/image_fallback_resolver.dart';
import '../../domain/entities/recipe.dart';

/// Renders a recipe's photo when an approved image is available, always
/// degrading gracefully to the recipe's [Recipe.emoji] on a themed
/// background — never a broken image icon, and never fabricated imagery.
///
/// Not wired into any screen yet: Sprint 5.5's design_system RecipeCard
/// already renders images via a raw ImageProvider without network-failure
/// handling, so wiring this in is left as deliberate follow-up rather than
/// touching that protected component here.
class RecipeImage extends StatelessWidget {
  const RecipeImage({
    required this.recipe,
    super.key,
    this.size = 56,
    this.borderRadius = AppRadius.largeRadius,
  });

  final Recipe recipe;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolution = resolveImageCandidates(
      metadata: recipe.imageMetadata,
      fallbackGlyph: recipe.emoji,
    );

    return ResolvedImage(
      resolution: resolution,
      semanticLabel: 'รูปภาพเมนู ${recipe.name}',
      size: size,
      borderRadius: borderRadius,
      loadedKey: ValueKey<String>('recipe-image-${recipe.id}'),
      exhaustedFallbackKey: ValueKey<String>('recipe-image-fallback-${recipe.id}'),
    );
  }
}
