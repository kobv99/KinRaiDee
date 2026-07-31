import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_section_header.dart';
import '../../../../core/design_system/components/app_skeleton.dart';
import '../../../../core/design_system/design_tokens/app_spacing.dart';
import '../../../../core/design_system/feature_components/recipe_card.dart';
import '../../../recipe/domain/entities/recipe_match.dart';
import '../../../recipe/presentation/pages/recipe_detail_page.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';

/// "5 เมนูน่าลองจาก[hero ingredient]" — reuses the EXISTING
/// [smartRecommendationProvider] / [recommendationSessionProvider] (already
/// used by the Recipe tab). This section does not add any new
/// recommendation logic; it only presents the existing engine's output
/// with the new visual design.
class TopPicksSection extends ConsumerWidget {
  const TopPicksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(smartRecommendationProvider);

    return recommendation.when(
      loading: () => _loadingRow(),
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
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: rec.primaryMatches.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final match = rec.primaryMatches[index];
                  return RecipeCard(
                    name: match.recipe.name,
                    pantryMatchPercent: match.scorePercent,
                    readiness: _readinessFor(match),
                    cookingTimeMinutes: match.recipe.cookTimeMinutes,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailPage(recipe: match.recipe),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  RecipeReadiness _readinessFor(RecipeMatch match) {
    if (match.canCook) return RecipeReadiness.ready;
    if (match.scorePercent >= 70) return RecipeReadiness.almostReady;
    return RecipeReadiness.pantryFriendly;
  }

  Widget _loadingRow() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) => const AppRecipeCardSkeleton(),
      ),
    );
  }
}
