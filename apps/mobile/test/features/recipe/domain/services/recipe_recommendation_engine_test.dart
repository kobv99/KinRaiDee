import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_match.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_recommendation.dart';
import 'package:mobile/features/recipe/domain/services/recipe_recommendation_engine.dart';

void main() {
  final now = DateTime.utc(2026, 7, 30, 8);
  const engine = RecipeRecommendationEngine();

  test('score is explainable and based on actual pantry matching', () {
    final result = engine
        .evaluateAll(
          matches: <RecipeMatch>[
            _match(id: 'fried-rice', score: .8, missing: 1),
          ],
          pantry: <Ingredient>[
            _pantry('rice', now, expiryDate: now.add(const Duration(days: 1))),
            _pantry('egg', now),
          ],
          evaluatedAt: now,
        )
        .single;

    expect(result.recipeMatchPercent, 80);
    expect(result.availableIngredientCount, 2);
    expect(result.totalIngredientCount, 3);
    expect(result.pantryCompletionPercent, 67);
    expect(result.usedPantryIngredientCount, 2);
    expect(result.pantryUtilizationPercent, 100);
    expect(result.shoppingPreview.single.canonicalIngredientId, 'sauce');
    expect(result.components.map((item) => item.id), contains('recipe_match'));
    expect(
      result.components.fold<double>(0, (sum, item) => sum + item.points),
      closeTo(result.score, .0001),
    );
    expect(result.reasons, isNotEmpty);
    expect(
      result.badges,
      contains(RecommendationBadge.usesExpiringIngredients),
    );
  });

  test('configuration changes weights without changing engine logic', () {
    const matchOnly = RecipeRecommendationEngine(
      configuration: RecommendationConfiguration(
        weights: RecommendationWeights(
          recipeMatch: 1,
          fewMissing: 0,
          expiringIngredients: 0,
          quickMeal: 0,
          lowComplexity: 0,
          favorite: 0,
          notRecentlyCooked: 0,
        ),
      ),
    );
    final result = matchOnly
        .evaluateAll(
          matches: <RecipeMatch>[_match(id: 'one', score: .82, missing: 1)],
          pantry: <Ingredient>[_pantry('rice', now)],
          evaluatedAt: now,
        )
        .single;

    expect(result.scorePercent, 82);
  });

  test('ranking is stable and uses recipe id as final tie-breaker', () {
    final results = engine.evaluateAll(
      matches: <RecipeMatch>[
        _match(id: 'b', score: .8),
        _match(id: 'a', score: .8),
      ],
      pantry: <Ingredient>[_pantry('rice', now), _pantry('egg', now)],
      evaluatedAt: now,
    );

    expect(
      results.map((item) => item.match.recipe.id),
      orderedEquals(<String>['a', 'b']),
    );
  });

  test('filters and sorting are applied by the domain engine', () {
    final results = engine.evaluateAll(
      matches: <RecipeMatch>[
        _match(id: 'slow', score: .95, cookTime: 60),
        _match(id: 'quick', score: .8, cookTime: 15),
        _match(id: 'weak', score: .4, cookTime: 10),
      ],
      pantry: <Ingredient>[_pantry('rice', now), _pantry('egg', now)],
      evaluatedAt: now,
      filter: const RecommendationFilter(minimumMatchPercent: 70),
      sort: RecommendationSort.fastest,
    );

    expect(
      results.map((item) => item.match.recipe.id),
      orderedEquals(<String>['quick', 'slow']),
    );
  });

  test('dashboard and why-not use the same explainable result data', () {
    final results = engine.evaluateAll(
      matches: <RecipeMatch>[
        _match(id: 'best', score: .95, missing: 0),
        _match(id: 'second', score: .8, missing: 1),
      ],
      pantry: <Ingredient>[_pantry('rice', now), _pantry('egg', now)],
      evaluatedAt: now,
    );
    final dashboard = RecommendationDashboard.from(results);

    expect(dashboard.totalRecipes, 2);
    expect(dashboard.pantryFriendly, 2);
    expect(results.first.whyRankedHigherThan(results.last), contains('Pantry'));
  });
}

RecipeMatch _match({
  required String id,
  required double score,
  int missing = 0,
  int cookTime = 20,
}) {
  const rice = RecipeIngredient(
    id: 'rice',
    name: 'Rice',
    quantity: 1,
    unit: 'piece',
    role: RecipeIngredientRole.primary,
  );
  const egg = RecipeIngredient(
    id: 'egg',
    name: 'Egg',
    quantity: 1,
    unit: 'piece',
    role: RecipeIngredientRole.secondary,
  );
  const sauce = RecipeIngredient(
    id: 'sauce',
    name: 'Sauce',
    quantity: 1,
    unit: 'piece',
    role: RecipeIngredientRole.secondary,
  );
  final recipe = Recipe(
    id: id,
    name: id,
    category: 'Thai',
    cookTimeMinutes: cookTime,
    servings: 1,
    ingredients: const <RecipeIngredient>[rice, egg, sauce],
    steps: const <String>[],
    heroIngredientId: 'rice',
  );
  return RecipeMatch(
    recipe: recipe,
    matchedIngredients: const <RecipeIngredient>[rice, egg],
    missingIngredients: missing == 0
        ? const <RecipeIngredient>[]
        : const <RecipeIngredient>[sauce],
    score: score,
  );
}

Ingredient _pantry(String id, DateTime now, {DateTime? expiryDate}) {
  return Ingredient(
    id: '$id-lot',
    name: id,
    category: 'test',
    emoji: '',
    quantity: 1,
    unit: 'piece',
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: id,
    canonicalUnitId: 'piece',
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}
