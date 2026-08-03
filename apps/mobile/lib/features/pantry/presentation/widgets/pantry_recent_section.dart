import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/models/ingredient.dart';
import '../../../../core/presentation/ingredient_presentation.dart';
import '../../../../core/presentation/unit_presentation.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/section_header.dart';

class PantryRecentSection extends ConsumerWidget {
  const PantryRecentSection({
    required this.ingredients,
    required this.onIngredientTap,
    super.key,
  });

  final List<Ingredient> ingredients;
  final ValueChanged<Ingredient> onIngredientTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'เพิ่มล่าสุด',
          subtitle: 'แตะรายการเพื่อแก้ไขได้ทันที',
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ingredients.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final ingredient = ingredients[index];

              return SizedBox(
                width: 168,
                child: AppCard(
                  onTap: () => onIngredientTap(ingredient),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryLight,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        child: Text(
                          IngredientPresentation.emoji(
                            ingredient,
                            ref.watch(canonicalIngredientRegistryProvider),
                          ),
                          style: const TextStyle(fontSize: 27),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ingredient.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.titleMedium,
                                  ),
                                ),
                                if (ingredient.isFavorite)
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 17,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              UnitPresentation.cookingQuantity(
                                ingredient.quantity,
                                ingredient.canonicalUnitId.isEmpty
                                    ? ingredient.unit
                                    : ingredient.canonicalUnitId,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
