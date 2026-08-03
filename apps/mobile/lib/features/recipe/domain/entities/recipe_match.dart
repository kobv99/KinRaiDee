import 'recipe.dart';
import 'recipe_compatibility.dart';
import 'recipe_ingredient.dart';

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.matchedIngredients,
    required this.missingIngredients,
    required this.score,
    this.mainIngredientCompatibility,
  });

  final Recipe recipe;
  final List<RecipeIngredient> matchedIngredients;
  final List<RecipeIngredient> missingIngredients;
  final double score;
  final MainIngredientCompatibilityResult? mainIngredientCompatibility;

  MainIngredientMatchTier? get mainIngredientMatchTier =>
      mainIngredientCompatibility?.tier;

  String get matchReason => mainIngredientCompatibility?.reason ?? '';

  bool get hasVerifiedMainIngredientMatch =>
      mainIngredientCompatibility?.isEligible == true;

  RecipeMatch withMainIngredientCompatibility(
    MainIngredientCompatibilityResult compatibility,
  ) {
    return RecipeMatch(
      recipe: recipe,
      matchedIngredients: matchedIngredients,
      missingIngredients: missingIngredients,
      score: score,
      mainIngredientCompatibility: compatibility,
    );
  }

  List<RecipeIngredient> get matchedPrimaryIngredients =>
      _withRole(matchedIngredients, RecipeIngredientRole.primary);

  List<RecipeIngredient> get matchedSecondaryIngredients =>
      _withRole(matchedIngredients, RecipeIngredientRole.secondary);

  List<RecipeIngredient> get matchedOptionalIngredients =>
      _withRole(matchedIngredients, RecipeIngredientRole.optional);

  List<RecipeIngredient> get missingPrimaryIngredients =>
      _withRole(missingIngredients, RecipeIngredientRole.primary);

  List<RecipeIngredient> get missingSecondaryIngredients =>
      _withRole(missingIngredients, RecipeIngredientRole.secondary);

  List<RecipeIngredient> get missingOptionalIngredients =>
      _withRole(missingIngredients, RecipeIngredientRole.optional);

  List<RecipeIngredient> get matchedRequiredIngredients => <RecipeIngredient>[
    ...matchedPrimaryIngredients,
    ...matchedSecondaryIngredients,
  ];

  List<RecipeIngredient> get missingRequiredIngredients => <RecipeIngredient>[
    ...missingPrimaryIngredients,
    ...missingSecondaryIngredients,
  ];

  int get missingPrimaryCount => missingPrimaryIngredients.length;
  int get missingSecondaryCount => missingSecondaryIngredients.length;
  int get missingRequiredCount => missingRequiredIngredients.length;
  int get missingOptionalCount => missingOptionalIngredients.length;

  bool get canCook => missingRequiredCount == 0;

  int get scorePercent => (score.clamp(0, 1) * 100).round();

  List<RecipeIngredient> _withRole(
    Iterable<RecipeIngredient> source,
    RecipeIngredientRole role,
  ) {
    final hero = recipe.heroIngredient;
    return source
        .where(
          (item) => item.effectiveRole(isHero: identical(item, hero)) == role,
        )
        .toList(growable: false);
  }
}
