import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/recipe_readiness_service.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';
import 'package:mobile/features/shopping/domain/services/shopping_recommendation_service.dart';

void main() {
  final now = DateTime.utc(2026, 7, 28, 10);
  final units = UnitConversionEngine.standard();
  final registry = _registry();
  final service = ShoppingRecommendationService(
    readinessService: RecipeReadinessService(
      registry: registry,
      unitEngine: units,
    ),
    registry: registry,
    unitEngine: units,
  );

  test('ranks deterministic cooking value and excludes optional-only items', () {
    final first = service.recommend(
      recipes: _recipes,
      pantry: <Ingredient>[_pantry('rice', 100, 'gram', now)],
      shoppingLists: const <ShoppingList>[],
      evaluatedAt: now,
    );
    final second = service.recommend(
      recipes: _recipes.reversed.toList(),
      pantry: <Ingredient>[_pantry('rice', 100, 'gram', now)],
      shoppingLists: const <ShoppingList>[],
      evaluatedAt: now,
    );

    expect(first.map((item) => item.canonicalIngredientId), <String>[
      'egg',
      'onion',
    ]);
    expect(
      first.map((item) => item.toJson()).toList(),
      second.map((item) => item.toJson()).toList(),
    );

    final egg = first.first;
    expect(egg.evidence.recipesUnlocked, 2);
    expect(egg.evidence.impactedRecipeCount, 2);
    expect(egg.recommendedQuantity, 2);
    expect(egg.targetShoppingQuantity, 2);
    expect(
      egg.evidence.reasonCodes.map((reason) => reason.name),
      contains('unlocksManyRecipes'),
    );
    expect(
      first.where((item) => item.canonicalIngredientId == 'cinnamon'),
      isEmpty,
    );
  });

  test('uses maximum single-Recipe shortage and subtracts active Shopping', () {
    final eggItem = ShoppingItemFactory(registry: registry, unitEngine: units)
        .create(
          id: 'shopping::egg',
          canonicalIngredientId: 'egg',
          quantity: 1,
          unit: 'piece',
          source: ShoppingSource.manual,
          createdAt: now,
        );
    final recommendations = service.recommend(
      recipes: _recipes,
      pantry: <Ingredient>[_pantry('rice', 100, 'gram', now)],
      shoppingLists: <ShoppingList>[
        ShoppingList(
          id: 'shopping',
          name: 'Shopping',
          items: [eggItem],
          createdAt: now,
          updatedAt: now,
        ),
      ],
      evaluatedAt: now,
    );

    final egg = recommendations.firstWhere(
      (item) => item.canonicalIngredientId == 'egg',
    );
    expect(egg.targetShoppingQuantity, 2);
    expect(egg.existingShoppingQuantity, 1);
    expect(egg.recommendedQuantity, 1);
  });

  test('canonical child Pantry satisfies the parent Recipe requirement', () {
    final recommendations = service.recommend(
      recipes: const <Recipe>[_porkRecipe],
      pantry: <Ingredient>[_pantry('minced_pork', 200, 'gram', now)],
      shoppingLists: const <ShoppingList>[],
      evaluatedAt: now,
    );

    expect(recommendations, isEmpty);
  });
}

final List<Recipe> _recipes = <Recipe>[
  const Recipe(
    id: 'egg-rice',
    name: 'Egg Rice',
    category: 'test',
    servings: 1,
    heroIngredientId: 'rice',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'rice',
        name: 'Rice',
        quantity: 100,
        unit: 'gram',
        role: RecipeIngredientRole.primary,
        weight: 70,
      ),
      RecipeIngredient(
        id: 'egg',
        name: 'Egg',
        quantity: 1,
        unit: 'piece',
        role: RecipeIngredientRole.secondary,
        weight: 30,
      ),
    ],
    steps: <String>[],
  ),
  const Recipe(
    id: 'omelette',
    name: 'Omelette',
    category: 'test',
    servings: 1,
    heroIngredientId: 'egg',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'egg',
        name: 'Egg',
        quantity: 2,
        unit: 'piece',
        role: RecipeIngredientRole.primary,
        weight: 100,
      ),
    ],
    steps: <String>[],
  ),
  const Recipe(
    id: 'onion-rice',
    name: 'Onion Rice',
    category: 'test',
    servings: 1,
    heroIngredientId: 'rice',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'rice',
        name: 'Rice',
        quantity: 100,
        unit: 'gram',
        role: RecipeIngredientRole.primary,
        weight: 70,
      ),
      RecipeIngredient(
        id: 'onion',
        name: 'Onion',
        quantity: 100,
        unit: 'gram',
        role: RecipeIngredientRole.secondary,
        weight: 30,
      ),
    ],
    steps: <String>[],
  ),
  const Recipe(
    id: 'cinnamon-rice',
    name: 'Cinnamon Rice',
    category: 'test',
    servings: 1,
    heroIngredientId: 'rice',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'rice',
        name: 'Rice',
        quantity: 100,
        unit: 'gram',
        role: RecipeIngredientRole.primary,
        weight: 90,
      ),
      RecipeIngredient(
        id: 'cinnamon',
        name: 'Cinnamon',
        quantity: 5,
        unit: 'gram',
        role: RecipeIngredientRole.optional,
        weight: 10,
      ),
    ],
    steps: <String>[],
  ),
];

const Recipe _porkRecipe = Recipe(
  id: 'garlic-pork',
  name: 'Garlic Pork',
  category: 'test',
  servings: 1,
  heroIngredientId: 'pork',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'pork',
      name: 'Pork',
      quantity: 200,
      unit: 'gram',
      role: RecipeIngredientRole.primary,
      weight: 100,
    ),
  ],
  steps: <String>[],
);

Ingredient _pantry(
  String canonicalId,
  double quantity,
  String unit,
  DateTime now,
) {
  final canonical = _registry().byId(canonicalId)!;
  return Ingredient(
    id: 'pantry::$canonicalId',
    name: canonical.displayName(),
    category: canonical.category,
    emoji: canonical.emoji,
    quantity: quantity,
    unit: unit,
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: canonicalId,
    canonicalUnitId: unit,
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

CanonicalIngredientRegistry _registry() {
  CanonicalIngredient ingredient(
    String id,
    String name,
    String unit, {
    String? parentId,
  }) {
    return CanonicalIngredient(
      id: id,
      canonicalName: name,
      localizedNames: <String, String>{'th': name},
      aliases: const <String>[],
      searchKeywords: const <String>[],
      category: 'test',
      defaultStorageType: IngredientStorageType.pantry,
      defaultPurchaseUnitId: unit,
      defaultInventoryUnitId: unit,
      parentId: parentId,
    );
  }

  return CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      ingredient('rice', 'Rice', 'gram'),
      ingredient('egg', 'Egg', 'piece'),
      ingredient('onion', 'Onion', 'gram'),
      ingredient('cinnamon', 'Cinnamon', 'gram'),
      ingredient('pork', 'Pork', 'gram'),
      ingredient('minced_pork', 'Minced Pork', 'gram', parentId: 'pork'),
    ],
  );
}
