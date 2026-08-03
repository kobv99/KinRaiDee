import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_section_header.dart';
import '../../../../core/design_system/components/app_skeleton.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/design_tokens/app_typography.dart';
import '../../../../core/design_system/feature_components/recipe_card.dart';
import '../../../recipe/domain/entities/recipe_match.dart';
import '../../../recipe/presentation/pages/recipe_detail_page.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import 'home_recipe_filter.dart';

const double _cardHeight = 220;

/// Top recipe picks row. Default state ("all") shows the existing
/// hero-ingredient recommendation ("5 เมนูน่าลองจาก...") from
/// [smartRecommendationProvider]. Any other [filter] switches to a
/// filtered slice of [recipeMatchesProvider] instead — both are existing
/// data sources; no new recommendation logic was added, only a second way
/// to present it.
class TopPicksSection extends ConsumerWidget {
  const TopPicksSection({super.key, required this.filter});

  final HomeRecipeFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filter != HomeRecipeFilter.all) {
      return _buildFiltered(context, ref);
    }
    return _buildHeroRecommendation(context, ref);
  }

  Widget _buildFiltered(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(recipeMatchesProvider);
    return matchesAsync.when(
      loading: _loadingRow,
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (matches) {
        final filtered = matches.where(_matchesFilter).toList(growable: false)
          ..sort((a, b) => b.scorePercent.compareTo(a.scorePercent));
        final top = filtered.take(8).toList(growable: false);

        if (top.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(_emptyLabel, style: AppTypography.bodySmall),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: _filteredTitle),
            const SizedBox(height: AppSpacing.md),
            _cardRow(context, top),
          ],
        );
      },
    );
  }

  bool _matchesFilter(RecipeMatch match) {
    return switch (filter) {
      HomeRecipeFilter.readyToCook => match.canCook,
      HomeRecipeFilter.pantryFriendly => match.scorePercent >= 70,
      HomeRecipeFilter.quick =>
        match.recipe.cookTimeMinutes > 0 && match.recipe.cookTimeMinutes <= 30,
      HomeRecipeFilter.all => true,
    };
  }

  String get _filteredTitle => switch (filter) {
    HomeRecipeFilter.readyToCook => 'เมนูที่พร้อมทำได้เลย',
    HomeRecipeFilter.pantryFriendly => 'เมนู Pantry Friendly',
    HomeRecipeFilter.quick => 'เมนูด่วน (ไม่เกิน 30 นาที)',
    HomeRecipeFilter.all => '',
  };

  String get _emptyLabel => switch (filter) {
    HomeRecipeFilter.readyToCook => 'ยังไม่มีเมนูที่พร้อมทำได้ทันที',
    HomeRecipeFilter.pantryFriendly => 'ยังไม่มีเมนูที่ตรงกับ Pantry Friendly',
    HomeRecipeFilter.quick => 'ยังไม่มีเมนูด่วนที่ตรงเงื่อนไข',
    HomeRecipeFilter.all => '',
  };

  Widget _buildHeroRecommendation(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(smartRecommendationProvider);

    return recommendation.when(
      loading: _loadingRow,
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (rec) {
        if (!rec.hasHero || rec.primaryMatches.isEmpty) {
          return const SizedBox.shrink();
        }

        final heroName = rec.hero!.name;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: '5 เมนูน่าลองจาก$heroName',
              actionLabel: rec.canRefresh ? 'เปลี่ยนชุด' : null,
              actionIcon: Icons.refresh,
              onActionTap: rec.canRefresh
                  ? () => ref
                        .read(recommendationSessionProvider.notifier)
                        .showNext(rec.totalHeroRecipes)
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            _cardRow(context, rec.primaryMatches),
          ],
        );
      },
    );
  }

  Widget _cardRow(BuildContext context, List<RecipeMatch> matches) {
    return SizedBox(
      height: _cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: matches.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final match = matches[index];
          return RecipeCard(
            name: match.recipe.name,
            pantryMatchPercent: match.scorePercent,
            readiness: _readinessFor(match),
            cookingTimeMinutes: match.recipe.cookTimeMinutes,
            imageMetadata: match.recipe.imageMetadata,
            placeholderEmoji: match.recipe.emoji,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => RecipeDetailPage(recipe: match.recipe),
              ),
            ),
          );
        },
      ),
    );
  }

  RecipeReadiness _readinessFor(RecipeMatch match) {
    if (match.canCook) return RecipeReadiness.ready;
    if (match.scorePercent >= 70) return RecipeReadiness.almostReady;
    return RecipeReadiness.pantryFriendly;
  }

  Widget _loadingRow() {
    return SizedBox(
      height: _cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => const AppRecipeCardSkeleton(),
      ),
    );
  }
}
