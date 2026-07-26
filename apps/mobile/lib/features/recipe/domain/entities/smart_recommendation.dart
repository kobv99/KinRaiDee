import 'recipe_match.dart';

enum HeroSelectionMode { automatic, manual, pinned }

class HeroIngredientOption {
  const HeroIngredientOption({
    required this.key,
    required this.name,
    required this.emoji,
    required this.recipeCount,
    this.readyCount = 0,
    this.bestScorePercent = 0,
    this.daysUntilExpiry,
  });

  final String key;
  final String name;
  final String emoji;
  final int recipeCount;
  final int readyCount;
  final int bestScorePercent;
  final int? daysUntilExpiry;
}

class SmartRecommendation {
  const SmartRecommendation({
    required this.heroOptions,
    required this.primaryMatches,
    required this.moreMatches,
    required this.totalHeroRecipes,
    required this.pageIndex,
    required this.pageCount,
    this.hero,
    this.heroSelectionMode = HeroSelectionMode.automatic,
    this.heroReason = '',
    this.requestedSelectionAvailable = true,
  });

  final HeroIngredientOption? hero;
  final List<HeroIngredientOption> heroOptions;
  final List<RecipeMatch> primaryMatches;
  final List<RecipeMatch> moreMatches;
  final int totalHeroRecipes;
  final int pageIndex;
  final int pageCount;
  final HeroSelectionMode heroSelectionMode;
  final String heroReason;
  final bool requestedSelectionAvailable;

  bool get hasHero => hero != null;
  bool get canRefresh => pageCount > 1;
  bool get isPinned => heroSelectionMode == HeroSelectionMode.pinned;
  bool get isAutomatic => heroSelectionMode == HeroSelectionMode.automatic;
}
