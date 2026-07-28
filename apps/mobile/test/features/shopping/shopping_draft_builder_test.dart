import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/services/shopping_draft_builder.dart';

void main() {
  final registry = _registry();
  final unitEngine = UnitConversionEngine.standard();
  final builder = ShoppingDraftBuilder(
    registry: registry,
    unitEngine: unitEngine,
  );
  final now = DateTime.utc(2026, 7, 26);

  test('builds Recipe shortages against Pantry with canonical IDs', () {
    final recipe = Recipe(
      id: 'omelette',
      name: 'Omelette',
      category: 'egg',
      servings: 2,
      ingredients: const <RecipeIngredient>[
        RecipeIngredient(id: 'egg', name: 'Egg', quantity: 4, unit: 'piece'),
      ],
      steps: const <String>[],
    );
    final pantry = <Ingredient>[
      Ingredient(
        id: 'egg-lot',
        name: 'Egg',
        category: 'protein',
        emoji: '',
        quantity: 2,
        unit: 'piece',
        createdAt: now,
        updatedAt: now,
        canonicalIngredientId: 'egg',
        canonicalUnitId: 'piece',
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    ];

    final list = builder.fromRecipe(
      listId: 'recipe-omelette',
      name: 'Omelette ingredients',
      recipe: recipe,
      pantry: pantry,
      servings: 2,
      createdAt: now,
    );

    expect(list.items, hasLength(1));
    expect(list.items.single.id, 'recipe-omelette::egg::piece');
    expect(list.items.single.canonicalIngredientId, 'egg');
    expect(list.items.single.quantity, 2);
    expect(list.items.single.unitId, 'piece');
    expect(list.items.single.source, ShoppingSource.recipe);
    expect(list.items.single.sourceReferenceId, 'omelette');
  });

  test('does not add ingredients already covered by Pantry', () {
    final recipe = Recipe(
      id: 'omelette',
      name: 'Omelette',
      category: 'egg',
      servings: 2,
      ingredients: const <RecipeIngredient>[
        RecipeIngredient(id: 'egg', name: 'Egg', quantity: 2, unit: 'piece'),
      ],
      steps: const <String>[],
    );
    final pantry = <Ingredient>[
      Ingredient(
        id: 'egg-lot',
        name: 'Egg',
        category: 'protein',
        emoji: '',
        quantity: 6,
        unit: 'piece',
        createdAt: now,
        updatedAt: now,
        canonicalIngredientId: 'egg',
        canonicalUnitId: 'piece',
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    ];

    final list = builder.fromRecipe(
      listId: 'covered',
      name: 'Covered',
      recipe: recipe,
      pantry: pantry,
      servings: 2,
      createdAt: now,
    );

    expect(list.items, isEmpty);
  });

  test('rejects Recipe ingredients outside the canonical registry', () {
    final recipe = Recipe(
      id: 'unknown',
      name: 'Unknown',
      category: 'other',
      ingredients: const <RecipeIngredient>[
        RecipeIngredient(
          id: 'mystery',
          name: 'Mystery',
          quantity: 1,
          unit: 'piece',
        ),
      ],
      steps: const <String>[],
    );

    expect(
      () => builder.fromRecipe(
        listId: 'unknown',
        name: 'Unknown',
        recipe: recipe,
        pantry: const <Ingredient>[],
        servings: 1,
        createdAt: now,
      ),
      throwsA(
        isA<ShoppingDomainException>().having(
          (error) => error.code,
          'code',
          'unknown_recipe_ingredient',
        ),
      ),
    );
  });

  test('rejects quantities rounded to zero by the unit precision policy', () {
    final factory = ShoppingItemFactory(
      registry: registry,
      unitEngine: unitEngine,
    );

    expect(
      () => factory.create(
        id: 'too-small',
        canonicalIngredientId: 'egg',
        quantity: 0.001,
        unit: 'piece',
        source: ShoppingSource.manual,
        createdAt: now,
      ),
      throwsA(
        isA<ShoppingDomainException>().having(
          (error) => error.code,
          'code',
          'quantity_below_unit_precision',
        ),
      ),
    );
  });
}

CanonicalIngredientRegistry _registry() {
  return CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'egg',
        canonicalName: 'Egg',
        localizedNames: const <String, String>{'th': 'Egg'},
        aliases: const <String>[],
        searchKeywords: const <String>[],
        category: 'protein',
        defaultStorageType: IngredientStorageType.refrigerated,
        defaultPurchaseUnitId: 'piece',
        defaultInventoryUnitId: 'piece',
      ),
    ],
  );
}
