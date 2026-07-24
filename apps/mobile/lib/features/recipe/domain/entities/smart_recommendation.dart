import 'recipe_match.dart';

class HeroIngredientOption {
  const HeroIngredientOption({
    required this.key,
    required this.name,
    required this.emoji,
    required this.recipeCount,
  });

  final String key;
  final String name;
  final String emoji;
  final int recipeCount;
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
  });

  final HeroIngredientOption? hero;
  final List<HeroIngredientOption> heroOptions;
  final List<RecipeMatch> primaryMatches;
  final List<RecipeMatch> moreMatches;
  final int totalHeroRecipes;
  final int pageIndex;
  final int pageCount;

  bool get hasHero => hero != null;
  bool get canRefresh => pageCount > 1;
}
