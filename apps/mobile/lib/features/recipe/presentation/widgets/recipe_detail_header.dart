import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_chip.dart';
import '../../../../core/design_system/components/app_icon_button.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/design_system/feature_components/ingredient_status_chip.dart';
import '../../../../core/design_system/feature_components/pantry_readiness_card.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_readiness.dart';

/// Recipe Detail hero + readiness section, matching the Sprint 5.5 mockup:
/// back/favorite/menu icons over the hero area, name + Pantry Friendly
/// badge, time/difficulty/servings row, then the readiness card and main
/// ingredients row.
///
/// Every number shown here comes directly from [readiness] (the same
/// [RecipeReadiness] object already computed by `recipeReadinessProvider`
/// in recipe_detail_page.dart) — no new readiness math was written.
class RecipeDetailHeader extends StatelessWidget {
  const RecipeDetailHeader({
    super.key,
    required this.recipe,
    required this.readiness,
    required this.onBack,
    required this.onAddMissing,
    this.isAddingMissing = false,
    required this.onStartCooking,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final Recipe recipe;
  final RecipeReadiness? readiness;
  final VoidCallback onBack;
  final VoidCallback? onAddMissing;
  final bool isAddingMissing;
  final VoidCallback onStartCooking;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroImagePlaceholder(
          emoji: recipe.emoji,
          onBack: onBack,
          isFavorite: isFavorite,
          onToggleFavorite: onToggleFavorite,
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(recipe.name, style: AppTypography.headline)),
                  if (readiness != null && readiness!.scorePercent >= 70)
                    const AppChip(label: 'Pantry Friendly', tone: AppChipTone.primary),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _MetaItem(icon: Icons.schedule, label: '${recipe.cookTimeMinutes} นาที'),
                  const SizedBox(width: AppSpacing.lg),
                  _MetaItem(icon: Icons.local_fire_department_outlined, label: recipe.difficulty),
                  const SizedBox(width: AppSpacing.lg),
                  _MetaItem(
                    icon: Icons.people_outline,
                    label: '${readiness?.servings ?? recipe.servings} คน',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              if (readiness != null) ...[
                PantryReadinessCard(
                  readyPercent: readiness!.scorePercent,
                  haveCount: readiness!.availableIngredients.length,
                  totalCount: readiness!.ingredients.length,
                  missingCount: readiness!.missingIngredients.length,
                  onAddMissingIngredients: onAddMissing,
                  isAddingMissing: isAddingMissing,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('วัตถุดิบหลัก', style: AppTypography.label),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: readiness!.ingredients
                      .where((item) => item.isPrimary)
                      .map(
                        (item) => IngredientStatusChip(
                          name: item.ingredient.name,
                          status: item.isAvailable
                              ? IngredientStatus.available
                              : IngredientStatus.missing,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      key: const ValueKey<String>('start-cooking-cta'),
                      label: 'เริ่มทำอาหาร',
                      onPressed: onStartCooking,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroImagePlaceholder extends StatelessWidget {
  const _HeroImagePlaceholder({
    required this.emoji,
    required this.onBack,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final String emoji;
  final VoidCallback onBack;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    // NOTE: the recipe data model has no real photo field (only an
    // `emoji` and an optional `sourceUrl`, which is a source link, not an
    // image). Rather than faking a photo, this uses a styled gradient +
    // large emoji placeholder. Wiring real photos would need a new
    // `imageUrl` field on Recipe plus an actual image asset/CDN — out of
    // scope here.
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primarySoft, AppColors.surfaceMuted],
                ),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 96))),
            ),
          ),
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppIconButton(icon: Icons.arrow_back, semanticLabel: 'ย้อนกลับ', onPressed: onBack),
                Row(
                  children: [
                    AppIconButton(
                      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                      semanticLabel: isFavorite ? 'เอาออกจากรายการโปรด' : 'บันทึกเป็นรายการโปรด',
                      foreground: isFavorite ? AppColors.primary : AppColors.textPrimary,
                      onPressed: onToggleFavorite,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppIconButton(icon: Icons.more_vert, semanticLabel: 'เมนูเพิ่มเติม', onPressed: null),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.bodySmall),
      ],
    );
  }
}
