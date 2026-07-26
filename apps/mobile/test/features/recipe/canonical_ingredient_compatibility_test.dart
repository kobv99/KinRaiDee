import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/pantry_deduction_planner.dart';
import 'package:mobile/features/recipe/domain/services/recipe_matcher.dart';
import 'package:mobile/features/recipe/domain/services/recipe_serving_calculator.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

void main() {
  final registry = CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'chicken',
        canonicalName: 'Chicken',
        localizedNames: const <String, String>{'th': 'ไก่'},
        aliases: const <String>['อกไก่'],
        searchKeywords: const <String>[],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'kilogram',
        defaultInventoryUnitId: 'gram',
      ),
    ],
  );
  final now = DateTime.utc(2026, 7, 26);
  final pantry = <Ingredient>[
    Ingredient(
      id: 'lot-1',
      name: 'ชื่อที่ผู้ใช้ตั้งเอง',
      category: 'protein',
      emoji: 'x',
      quantity: 500,
      unit: 'กรัม',
      canonicalIngredientId: 'chicken',
      canonicalUnitId: 'gram',
      canonicalMappingStatus: CanonicalMappingStatus.mapped,
      createdAt: now,
      updatedAt: now,
    ),
  ];
  final recipe = Recipe(
    id: 'chicken_recipe',
    name: 'Chicken recipe',
    category: 'test',
    difficulty: 'easy',
    cookTimeMinutes: 10,
    ingredients: const <RecipeIngredient>[
      RecipeIngredient(id: 'chicken', name: 'ไก่', quantity: 250, unit: 'กรัม'),
    ],
    steps: const <String>['Cook'],
    servings: 1,
    heroIngredientId: 'chicken',
  );

  test('Pantry and Recipe match by canonical ID despite unrelated text', () {
    final matches = RecipeMatcher(
      registry: registry,
    ).match(recipes: <Recipe>[recipe], pantry: pantry);
    final plan = const RecipeServingCalculator().calculate(
      recipe: recipe,
      pantry: pantry,
      servings: 1,
      registry: registry,
    );

    expect(matches.single.canCook, isTrue);
    expect(plan.ingredients.single.status, PantryQuantityStatus.enough);
  });

  test('Recommendation and deduction retain canonical identity', () {
    final matches = RecipeMatcher(
      registry: registry,
    ).match(recipes: <Recipe>[recipe], pantry: pantry);
    final recommendation = const SmartRecommendationEngine().build(
      matches: matches,
      pantry: pantry,
      registry: registry,
    );
    final servingPlan = const RecipeServingCalculator().calculate(
      recipe: recipe,
      pantry: pantry,
      servings: 1,
      registry: registry,
    );
    final deduction = const PantryDeductionPlanner().build(
      servingPlan: servingPlan,
      pantry: pantry,
      registry: registry,
    );
    final transaction = const PantryDeductionPlanner().createTransaction(
      plan: deduction,
      selectedLineKeys: <String>{'chicken'},
      quantitiesByLineKey: <String, double>{'chicken': 250},
    );

    expect(recommendation.hero?.key, 'chicken');
    expect(transaction.changes.single.canonicalIngredientId, 'chicken');
    expect(transaction.changes.single.canonicalUnitId, 'gram');
  });
}
