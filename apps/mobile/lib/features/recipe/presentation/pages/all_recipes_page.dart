import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/recipe.dart';
import '../providers/recipe_provider.dart';
import '../widgets/recipe_image.dart';
import 'recipe_detail_page.dart';

class AllRecipesPage extends ConsumerWidget {
  const AllRecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('สูตรทั้งหมด')),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _LoadError(onRetry: () => ref.invalidate(recipesProvider)),
        data: (items) {
          final sorted = List<Recipe>.of(items)
            ..sort((first, second) => first.name.compareTo(second.name));
          if (sorted.isEmpty) {
            return const _EmptyRecipes();
          }
          final favoriteIds = ref.watch(favoriteRecipeIdsProvider);
          return ListView(
            key: const ValueKey<String>('all-recipes-list'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              const _FreedomNotice(),
              const SizedBox(height: AppSpacing.sm),
              ...sorted.map(
                (recipe) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _RecipeListTile(
                    recipe: recipe,
                    isFavorite: favoriteIds.contains(recipe.id),
                    onTap: () => _openRecipe(context, recipe),
                    onToggleFavorite: () => ref
                        .read(favoriteRecipeIdsProvider.notifier)
                        .toggle(recipe.id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRecipe(BuildContext context, Recipe recipe) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipe: recipe)),
    );
  }
}

class _RecipeListTile extends StatelessWidget {
  const _RecipeListTile({
    required this.recipe,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Recipe recipe;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: ValueKey<String>('all-recipe-${recipe.id}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          RecipeImage(recipe: recipe, size: 52),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(_subtitle(recipe), style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          IconButton(
            key: ValueKey<String>('all-recipe-favorite-${recipe.id}'),
            tooltip: isFavorite ? 'เอาออกจากรายการโปรด' : 'เพิ่มในรายการโปรด',
            onPressed: onToggleFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  String _subtitle(Recipe recipe) {
    final parts = <String>[];
    if (recipe.category.trim().isNotEmpty) {
      parts.add(recipe.category);
    }
    if (recipe.cookTimeMinutes > 0) {
      parts.add('${recipe.cookTimeMinutes} นาที');
    }
    return parts.isEmpty
        ? 'เปิดสูตรและตัดสินใจได้ตามต้องการ'
        : parts.join(' · ');
  }
}

class _FreedomNotice extends StatelessWidget {
  const _FreedomNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey<String>('all-recipes-freedom-notice'),
      backgroundColor: AppColors.primaryLight,
      showBorder: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book_outlined, color: AppColors.primaryDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'รายการนี้ไม่จำกัดตามคำแนะนำจาก Pantry คุณเลือกเปิดสูตรใดก็ได้ และเริ่มทำอาหารได้ตามต้องการ',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecipes extends StatelessWidget {
  const _EmptyRecipes();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.menu_book_outlined,
      title: 'ยังไม่มีข้อมูลสูตรอาหาร',
      description: 'ยังไม่มีข้อมูลสูตรอาหารในอุปกรณ์นี้',
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'โหลดสูตรทั้งหมดไม่สำเร็จ',
      description: 'ข้อมูลเดิมยังคงปลอดภัย กรุณาลองอีกครั้ง',
      actionLabel: 'ลองอีกครั้ง',
      onActionPressed: onRetry,
    );
  }
}
