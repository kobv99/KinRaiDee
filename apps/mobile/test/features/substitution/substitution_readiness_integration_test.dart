import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_readiness.dart';
import 'package:mobile/features/recipe/domain/services/recipe_readiness_service.dart';

void main() {
  test('accepted Pantry substitute changes Missing to Substituted', () {
    final now = DateTime.utc(2026, 7, 29);
    final registry = CanonicalIngredientRegistry(
      ingredients: [_canonical('fish_sauce'), _canonical('soy_sauce')],
    );
    final result =
        RecipeReadinessService(
          registry: registry,
          unitEngine: UnitConversionEngine.standard(),
        ).evaluate(
          recipe: const Recipe(
            id: 'recipe',
            name: 'Recipe',
            category: 'test',
            servings: 1,
            ingredients: [
              RecipeIngredient(
                id: 'fish_sauce',
                name: 'Fish sauce',
                quantity: 1,
                unit: 'tablespoon',
              ),
            ],
            steps: [],
          ),
          pantry: [
            Ingredient(
              id: 'soy',
              name: 'Soy sauce',
              category: 'test',
              emoji: '',
              quantity: 2,
              unit: 'tablespoon',
              createdAt: now,
              updatedAt: now,
              canonicalIngredientId: 'soy_sauce',
              canonicalUnitId: 'tablespoon',
              canonicalMappingStatus: CanonicalMappingStatus.mapped,
            ),
          ],
          servings: 1,
          evaluatedAt: now,
          acceptedSubstitutions: const {'fish_sauce': 'soy_sauce'},
        );

    expect(
      result.ingredients.single.status,
      RecipeIngredientReadinessStatus.substituted,
    );
    expect(result.ingredients.single.needsShopping, isFalse);
    expect(result.canCook, isTrue);
  });
}

CanonicalIngredient _canonical(String id) => CanonicalIngredient(
  id: id,
  canonicalName: id,
  localizedNames: {'th': id},
  aliases: const [],
  searchKeywords: const [],
  category: 'test',
  defaultStorageType: IngredientStorageType.pantry,
  defaultPurchaseUnitId: 'tablespoon',
  defaultInventoryUnitId: 'tablespoon',
);
