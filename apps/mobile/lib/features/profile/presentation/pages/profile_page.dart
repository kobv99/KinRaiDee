import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../pantry/presentation/providers/cooking_history_provider.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/presentation/pages/recipe_detail_page.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../../../recipe/presentation/widgets/recipe_image.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantryCount = ref.watch(pantryProvider).length;
    final historyCount = ref.watch(cookingHistoryProvider).length;
    final favoriteIds = ref.watch(favoriteRecipeIdsProvider);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final favoriteRecipes = recipes
        .where((recipe) => favoriteIds.contains(recipe.id))
        .toList(growable: false)
      ..sort((first, second) => first.name.compareTo(second.name));

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: AppSpacing.md),
          _StatsRow(
            favoriteCount: favoriteIds.length,
            pantryCount: pantryCount,
            historyCount: historyCount,
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            icon: Icons.favorite_outline,
            title: 'สูตรโปรด',
            subtitle: favoriteRecipes.isEmpty
                ? 'ยังไม่มีสูตรที่บันทึกไว้'
                : '${favoriteRecipes.length} สูตร',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (favoriteRecipes.isEmpty)
            const EmptyState(
              key: ValueKey<String>('profile-favorites-empty'),
              icon: Icons.favorite_border,
              title: 'ยังไม่มีสูตรโปรด',
              description: 'กดไอคอนหัวใจที่สูตรอาหารเพื่อบันทึกไว้ที่นี่',
            )
          else
            ...favoriteRecipes.map(
              (recipe) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _FavoriteRecipeTile(recipe: recipe),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(icon: Icons.info_outline, title: 'เกี่ยวกับแอป'),
          const SizedBox(height: AppSpacing.sm),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KinRaiDee', style: AppTextStyles.titleMedium),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  'ผู้ช่วยจัดการวัตถุดิบ วางแผนเมนู และรายการซื้อของ ข้อมูลทั้งหมดเก็บไว้ในอุปกรณ์นี้เท่านั้น',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.primaryLight,
      showBorder: false,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surface,
            child: Icon(
              Icons.person_outline,
              size: 30,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สวัสดี 👋', style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'ข้อมูลของคุณ Pantry สูตรโปรด และประวัติการทำอาหาร',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.favoriteCount,
    required this.pantryCount,
    required this.historyCount,
  });

  final int favoriteCount;
  final int pantryCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.favorite_outline,
            value: favoriteCount,
            label: 'สูตรโปรด',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_2_outlined,
            value: pantryCount,
            label: 'วัตถุดิบใน Pantry',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.history,
            value: historyCount,
            label: 'ประวัติทำอาหาร',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryDark),
          const SizedBox(height: AppSpacing.xs),
          Text('$value', style: AppTextStyles.titleLarge),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _FavoriteRecipeTile extends ConsumerWidget {
  const _FavoriteRecipeTile({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      key: ValueKey<String>('profile-favorite-${recipe.id}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipe: recipe)),
      ),
      child: Row(
        children: [
          RecipeImage(recipe: recipe, size: 44),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              recipe.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge,
            ),
          ),
          IconButton(
            key: ValueKey<String>('profile-favorite-remove-${recipe.id}'),
            tooltip: 'เอาออกจากรายการโปรด',
            onPressed: () =>
                ref.read(favoriteRecipeIdsProvider.notifier).toggle(recipe.id),
            icon: const Icon(Icons.favorite, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
