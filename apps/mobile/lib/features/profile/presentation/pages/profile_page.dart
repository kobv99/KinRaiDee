import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_empty_state.dart';
import '../../../../core/design_system/components/app_section_header.dart';
import '../../../../core/design_system/components/responsive_content.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../pantry/presentation/pages/cooking_history_page.dart';
import '../../../pantry/presentation/providers/cooking_history_provider.dart';
import '../../../recipe/domain/entities/recipe.dart';
import '../../../recipe/presentation/pages/recipe_detail_page.dart';
import '../../../recipe/presentation/providers/favorite_recipe_ids_provider.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../providers/default_servings_provider.dart';

/// Profile as a personalization/settings hub, not a second dashboard:
/// Home already shows Pantry/recipe stats, so this screen intentionally
/// does not repeat that — it holds things a person configures once and
/// their own history, per the Round 2 product review.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyCount = ref.watch(cookingHistoryProvider).length;
    final favoriteIds = ref.watch(favoriteRecipeIdsProvider);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final favoriteRecipes =
        recipes
            .where((recipe) => favoriteIds.contains(recipe.id))
            .toList(growable: false)
          ..sort((first, second) => first.name.compareTo(second.name));

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: ResponsiveContent(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontalPhone,
            AppSpacing.lg,
            AppSpacing.pageHorizontalPhone,
            AppSpacing.xxxl,
          ),
          children: [
            const _ProfileHeader(),
            const SizedBox(height: AppSpacing.xxl),
            const AppSectionHeader(title: 'การตั้งค่าเริ่มต้น'),
            const SizedBox(height: AppSpacing.md),
            const _DefaultServingsSetting(),
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
            const AppSectionHeader(title: 'ประวัติ'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              key: const ValueKey<String>('profile-cooking-history'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const CookingHistoryPage(),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'ประวัติการทำอาหาร',
                      style: AppTypography.label,
                    ),
                  ),
                  Text('$historyCount รายการ', style: AppTypography.caption),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right, size: 20),
                ],
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
                  'ตั้งค่าเริ่มต้น ดูสูตรโปรด และประวัติการทำอาหารของคุณ',
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

/// The only Round 2 "personalization" setting wired to a real, working
/// effect: it changes the starting serving count the cooking wizard opens
/// with. Food preferences / notifications / language / theme / backup
/// were deliberately NOT added here — this app has no dietary-preference
/// data, no notification pipeline, no i18n, no second theme, and no
/// backup/export path to back them with, and a control that does nothing
/// is worse than no control (see Round 2 review, "every visible control
/// must work").
class _DefaultServingsSetting extends ConsumerWidget {
  const _DefaultServingsSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servings = ref.watch(defaultServingsProvider) ?? 2;

    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.groups_2_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จำนวนคนเริ่มต้น', style: AppTypography.label),
                Text(
                  'ใช้เป็นค่าเริ่มต้นเมื่อเริ่มทำอาหารสูตรใหม่',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey<String>('default-servings-decrement'),
            tooltip: 'ลดจำนวนคน',
            onPressed: servings > 1
                ? () => ref
                      .read(defaultServingsProvider.notifier)
                      .set(servings - 1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$servings', style: AppTypography.title),
          IconButton(
            key: const ValueKey<String>('default-servings-increment'),
            tooltip: 'เพิ่มจำนวนคน',
            onPressed: servings < 12
                ? () => ref
                      .read(defaultServingsProvider.notifier)
                      .set(servings + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
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
        MaterialPageRoute<void>(
          builder: (_) => RecipeDetailPage(recipe: recipe),
        ),
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
