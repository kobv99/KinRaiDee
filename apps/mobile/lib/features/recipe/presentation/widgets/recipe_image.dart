import 'package:flutter/material.dart';

import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_radius.dart';
import '../../domain/entities/recipe.dart';

/// Renders a recipe's photo when available, always degrading gracefully to
/// the recipe's [Recipe.emoji] on a themed background — never a broken
/// image icon, and never fabricated imagery.
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
    final imageUrl = recipe.imageUrl;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? _EmojiFallback(emoji: recipe.emoji, size: size)
            : Image.network(
                imageUrl,
                key: ValueKey<String>('recipe-image-${recipe.id}'),
                fit: BoxFit.cover,
                width: size,
                height: size,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return _EmojiFallback(emoji: recipe.emoji, size: size);
                },
                errorBuilder: (context, error, stackTrace) {
                  return _EmojiFallback(
                    key: ValueKey<String>('recipe-image-fallback-${recipe.id}'),
                    emoji: recipe.emoji,
                    size: size,
                  );
                },
              ),
      ),
    );
  }
}

class _EmojiFallback extends StatelessWidget {
  const _EmojiFallback({required this.emoji, required this.size, super.key});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}
