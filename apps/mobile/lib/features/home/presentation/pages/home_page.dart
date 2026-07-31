import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/responsive_content.dart';
import '../../../../core/design_system/design_tokens/app_colors.dart';
import '../../../../core/design_system/design_tokens/app_radius.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../widgets/daily_summary_card.dart';
import '../widgets/expiring_soon_section.dart';
import '../widgets/home_recipe_filter.dart';
import '../widgets/top_picks_section.dart';

/// Home screen, rebuilt per the Sprint 5.5 Design Acceptance Review.
///
/// Composition is deliberately minimal: header, greeting, one summary
/// card, top recipe picks, search entry point. The previous version
/// reused the full Pantry-dashboard layout (expiry tables, category
/// counts, "ควรใช้ก่อน" list, full-width "เปิดคลังวัตถุดิบ" button) with
/// new colors on top — that content has been removed from Home entirely.
/// It still exists on the Pantry tab, unchanged.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.onOpenPantry, this.onOpenRecipes});

  final VoidCallback onOpenPantry;
  final VoidCallback? onOpenRecipes;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  HomeRecipeFilter _filter = HomeRecipeFilter.all;

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(recipeMatchesProvider);
    final totalRecipes = matchesAsync.maybeWhen(data: (m) => m.length, orElse: () => 0);
    final readyToCookCount = matchesAsync.maybeWhen(
      data: (m) => m.where((match) => match.canCook).length,
      orElse: () => 0,
    );
    final pantryFriendlyCount = matchesAsync.maybeWhen(
      data: (m) => m.where((match) => match.scorePercent >= 70).length,
      orElse: () => 0,
    );
    final quickRecipeCount = matchesAsync.maybeWhen(
      data: (m) => m
          .where((match) => match.recipe.cookTimeMinutes > 0 && match.recipe.cookTimeMinutes <= 30)
          .length,
      orElse: () => 0,
    );
    final expiringSoonIngredients = ref.watch(
      pantryProvider.select((ingredients) {
        final filtered = ingredients.where((i) {
          final days = i.daysUntilExpiry;
          return !i.isExpired && days != null && days <= 7;
        }).toList(growable: false);
        filtered.sort((a, b) {
          final da = a.daysUntilExpiry ?? 9999;
          final db = b.daysUntilExpiry ?? 9999;
          return da.compareTo(db);
        });
        return filtered;
      }),
    );
    final expiringSoonCount = expiringSoonIngredients.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveContent(
          child: RefreshIndicator(
            onRefresh: () => ref.read(pantryProvider.notifier).reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                // 1. Compact header
                Row(
                  children: [
                    const Text('KinRaiDee', style: AppTypography.title),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // 2-3. Greeting + primary question
                Text(_greeting(), style: AppTypography.bodySmall),
                const SizedBox(height: 2),
                const Text('วันนี้อยากกินอะไรดี?', style: AppTypography.headline),
                const SizedBox(height: AppSpacing.lg),
                // 4. Daily summary — one card, interactive filter
                DailySummaryCard(
                  totalRecipes: totalRecipes,
                  readyToCookCount: readyToCookCount,
                  pantryFriendlyCount: pantryFriendlyCount,
                  quickRecipeCount: quickRecipeCount,
                  expiringSoonCount: expiringSoonCount,
                  selectedFilter: _filter,
                  onFilterSelected: (next) => setState(
                    () => _filter = _filter == next ? HomeRecipeFilter.all : next,
                  ),
                  onOpenPantry: widget.onOpenPantry,
                ),
                const SizedBox(height: AppSpacing.xl),
                // 5-6. Top picks + เปลี่ยนชุด (recipes appear above the fold)
                TopPicksSection(filter: _filter),
                const SizedBox(height: AppSpacing.xl),
                // Brought back per user testing feedback: compact expiry
                // awareness (top 3 only, not the full old dashboard).
                ExpiringSoonSection(
                  ingredients: expiringSoonIngredients,
                  onOpenPantry: widget.onOpenPantry,
                ),
                if (expiringSoonIngredients.isNotEmpty)
                  const SizedBox(height: AppSpacing.xl),
                // 7. Search field — routes to Recipe tab, where search lives
                _SearchEntryField(onTap: widget.onOpenRecipes ?? widget.onOpenPantry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'สวัสดีตอนเช้า 🌤️';
  if (hour < 17) return 'สวัสดีตอนบ่าย ☀️';
  return 'สวัสดีตอนเย็น 🌇';
}

class _SearchEntryField extends StatelessWidget {
  const _SearchEntryField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadius.pillRadius,
      child: InkWell(
        borderRadius: AppRadius.pillRadius,
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text('ค้นหาสูตรอาหาร...', style: AppTypography.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
