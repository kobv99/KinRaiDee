import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/recipe_candidate_service.dart';
import 'package:mobile/features/recipe/domain/services/recipe_readiness_service.dart';

void main() {
  final now = DateTime.utc(2026, 7, 30);
  final registry = CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      _canonical('chili', IngredientTrackingType.presenceOnly),
      _canonical('soy_sauce', IngredientTrackingType.stockBased),
      _canonical('egg', IngredientTrackingType.countBased),
    ],
  );
  final readiness = RecipeReadinessService(
    registry: registry,
    unitEngine: UnitConversionEngine.standard(),
  );

  test('presence-only matching ignores piece-to-gram unit mismatch', () {
    final result = readiness.evaluate(
      recipe: _recipe(
        'chili-recipe',
        const RecipeIngredient(
          id: 'chili',
          name: 'Chili',
          quantity: 20,
          unit: 'gram',
          role: RecipeIngredientRole.primary,
        ),
      ),
      pantry: <Ingredient>[_pantry('chili', 'piece', 1, now)],
      servings: 1,
      evaluatedAt: now,
    );

    expect(result.scorePercent, 100);
    expect(result.missingIngredients, isEmpty);
  });

  test('stock matching checks availability instead of exact quantity', () {
    final result = readiness.evaluate(
      recipe: _recipe(
        'sauce-recipe',
        const RecipeIngredient(
          id: 'soy_sauce',
          name: 'Soy Sauce',
          quantity: 3,
          unit: 'tablespoon',
          role: RecipeIngredientRole.primary,
        ),
      ),
      pantry: <Ingredient>[_pantry('soy_sauce', 'bottle', 1, now)],
      servings: 1,
      evaluatedAt: now,
    );

    expect(result.scorePercent, 100);
  });

  test('almost-ready recipe remains a candidate without its sole primary', () {
    final candidates = RecipeCandidateService(readinessService: readiness)
        .findCandidates(
          recipes: <Recipe>[
            _recipe(
              'missing-chili',
              const RecipeIngredient(
                id: 'chili',
                name: 'Chili',
                quantity: 1,
                unit: 'piece',
                role: RecipeIngredientRole.primary,
              ),
            ),
          ],
          pantry: const <Ingredient>[],
          evaluatedAt: now,
        );

    expect(candidates.single.recipe.id, 'missing-chili');
    expect(candidates.single.missingRequiredCount, 1);
  });
}

CanonicalIngredient _canonical(String id, IngredientTrackingType trackingType) {
  return CanonicalIngredient(
    id: id,
    canonicalName: id,
    localizedNames: <String, String>{'th': id},
    aliases: const <String>[],
    searchKeywords: const <String>[],
    category: 'test',
    defaultStorageType: IngredientStorageType.pantry,
    defaultPurchaseUnitId: 'piece',
    defaultInventoryUnitId: 'piece',
    trackingType: trackingType,
  );
}

Recipe _recipe(String id, RecipeIngredient ingredient) {
  return Recipe(
    id: id,
    name: id,
    category: 'test',
    servings: 1,
    heroIngredientId: ingredient.id,
    ingredients: <RecipeIngredient>[ingredient],
    steps: const <String>[],
  );
}

Ingredient _pantry(String id, String unit, double quantity, DateTime now) {
  return Ingredient(
    id: '$id-lot',
    name: id,
    category: 'test',
    emoji: '',
    quantity: quantity,
    unit: unit,
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: id,
    canonicalUnitId: unit,
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}
