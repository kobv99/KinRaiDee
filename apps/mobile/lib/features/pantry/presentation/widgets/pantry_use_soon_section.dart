import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/models/ingredient.dart';
import '../../../recipe/domain/services/main_ingredient_resolver.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../../domain/services/pantry_expiry_priority.dart';

class PantryUseSoonSection extends ConsumerWidget {
  const PantryUseSoonSection({
    required this.ingredients,
    required this.onFindRecipes,
    this.loadingIngredientId,
    super.key,
  });

  final List<Ingredient> ingredients;
  final ValueChanged<Ingredient> onFindRecipes;
  final String? loadingIngredientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    final recipesAsync = ref.watch(recipesProvider);
    final isCoverageLoading = recipesAsync.when(
      data: (_) => false,
      loading: () => true,
      error: (_, _) => false,
    );
    final coverageFailed = recipesAsync.when(
      data: (_) => false,
      loading: () => false,
      error: (_, _) => true,
    );
    final coverageByIngredientId = recipesAsync.when(
      data: (recipes) {
        final resolver = const MainIngredientResolver();
        final coverage = <String, MainIngredientResolution>{};

        for (final ingredient in ingredients) {
          final resolution = resolver.resolve(
            pantryIngredientName: ingredient.name,
            canonicalIngredientId: ingredient.canonicalIngredientId,
            registry: ref.watch(canonicalIngredientRegistryProvider),
            recipes: recipes,
          );
          if (resolution != null) {
            coverage[ingredient.id] = resolution;
          }
        }

        return coverage;
      },
      loading: () => const <String, MainIngredientResolution>{},
      error: (_, _) => const <String, MainIngredientResolution>{},
    );
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule_rounded, color: colors.error),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ควรใช้ก่อน',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'เลือกของใกล้หมดอายุเพื่อหาเมนูได้ทันที',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...ingredients.indexed.map((entry) {
            final index = entry.$1;
            final ingredient = entry.$2;
            final isOpeningRecipe = loadingIngredientId == ingredient.id;
            final coverage = coverageByIngredientId[ingredient.id];
            final canFindRecipes = coverage != null && !coverageFailed;

            return Column(
              children: [
                if (index > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Text(
                        ingredient.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ingredient.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: 2,
                              children: [
                                Text(
                                  PantryExpiryPriority.urgencyLabel(ingredient),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  _coverageLabel(
                                    coverage: coverage,
                                    loading: isCoverageLoading,
                                    failed: coverageFailed,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: coverage != null
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed:
                            isOpeningRecipe ||
                                isCoverageLoading ||
                                !canFindRecipes
                            ? null
                            : () => onFindRecipes(ingredient),
                        icon: _buttonIcon(
                          isOpeningRecipe: isOpeningRecipe,
                          isCoverageLoading: isCoverageLoading,
                          coverageFailed: coverageFailed,
                          hasCoverage: coverage != null,
                        ),
                        label: Text(
                          _buttonLabel(
                            isCoverageLoading: isCoverageLoading,
                            coverageFailed: coverageFailed,
                            hasCoverage: coverage != null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

String _coverageLabel({
  required MainIngredientResolution? coverage,
  required bool loading,
  required bool failed,
}) {
  if (loading) {
    return '• กำลังตรวจสูตร';
  }
  if (failed) {
    return '• ตรวจสูตรไม่ได้';
  }
  if (coverage == null) {
    return '• ยังไม่มีสูตร';
  }
  return '• มี ${coverage.recipeCount} สูตร';
}

String _buttonLabel({
  required bool isCoverageLoading,
  required bool coverageFailed,
  required bool hasCoverage,
}) {
  if (isCoverageLoading) {
    return 'กำลังตรวจ';
  }
  if (coverageFailed) {
    return 'ตรวจไม่ได้';
  }
  return hasCoverage ? 'หาเมนู' : 'ยังไม่มีสูตร';
}

Widget _buttonIcon({
  required bool isOpeningRecipe,
  required bool isCoverageLoading,
  required bool coverageFailed,
  required bool hasCoverage,
}) {
  if (isOpeningRecipe || isCoverageLoading) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
  if (coverageFailed) {
    return const Icon(Icons.error_outline_rounded);
  }
  if (!hasCoverage) {
    return const Icon(Icons.menu_book_outlined);
  }
  return const Icon(Icons.restaurant_menu_rounded);
}
