import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_empty_state.dart';
import '../../../../core/design_system/components/app_section_header.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/presentation/providers/cooking_history_provider.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/presentation/pages/recipe_detail_page.dart';
import '../../../recipe/presentation/providers/favorite_recipe_ids_provider.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';

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
          AppSpacing.pageHorizontalPhone,
          AppSpacing.lg,
          AppSpacing.pageHorizontalPhone,
          AppSpacing.xxxl,
        ),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: AppSpacing.lg),
          _StatsRow(
            favoriteCount: favoriteIds.length,
            pantryCount: pantryCount,
            historyCount: historyCount,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(
            title: 'สูตรโปรด',
            subtitle: favoriteRecipes.isEmpty
                ? 'ยังไม่มีสูตรที่บันทึกไว้'
                : '${favoriteRecipes.length} สูตร',
          ),
          const SizedBox(height: AppSpacing.md),
          if (favoriteRecipes.isEmpty)
            const AppCard(
              key: ValueKey<String>('profile-favorites-empty'),
              child: AppEmptyState(
                icon: Icons.favorite_border,
                message: 'กดไอคอนหัวใจที่สูตรอาหารเพื่อบันทึกไว้ที่นี่',
              ),
            )
          else
            ...favoriteRecipes.map(
              (recipe) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FavoriteRecipeTile(recipe: recipe),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          const AppSectionHeader(title: 'เกี่ยวกับแอป'),
          const SizedBox(height: AppSpacing.md),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KinRaiDee', style: AppTypography.title),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'ผู้ช่วยจัดการวัตถุดิบ วางแผนเมนู และรายการซื้อของ ข้อมูลทั้งหมดเก็บไว้ในอุปกรณ์นี้เท่านั้น',
                  style: AppTypography.body,
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
      bordered: false,
      color: AppColors.primarySoft,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surface,
            child: Icon(
              Icons.person_outline,
              size: 30,
              color: AppColors.primaryPressed,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('สวัสดี 👋', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ข้อมูลของคุณ Pantry สูตรโปรด และประวัติการทำอาหาร',
                  style: AppTypography.body,
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
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_2_outlined,
            value: pantryCount,
            label: 'วัตถุดิบใน Pantry',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
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
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryPressed),
          const SizedBox(height: AppSpacing.sm),
          Text('$value', style: AppTypography.title),
          Text(label, style: AppTypography.caption),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => RecipeDetailPage(recipe: recipe)),
      ),
      child: Row(
        children: [
          Text(recipe.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              recipe.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label,
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
