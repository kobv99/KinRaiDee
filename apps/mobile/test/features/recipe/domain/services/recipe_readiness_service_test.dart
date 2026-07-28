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
  final now = DateTime.utc(2026, 7, 28, 8);
  final service = RecipeReadinessService(
    registry: _registry,
    unitEngine: UnitConversionEngine.standard(),
  );

  test('missing garnish reduces readiness much less than missing main protein', () {
    final recipe = _recipe();
    final beefReady = service.evaluate(
      recipe: recipe,
      pantry: <Ingredient>[_pantry('beef', 1, 'kilogram', now)],
      servings: 2,
      evaluatedAt: now,
    );
    final garnishOnly = service.evaluate(
      recipe: recipe,
      pantry: <Ingredient>[_pantry('pepper', 1, 'piece', now)],
      servings: 2,
      evaluatedAt: now,
    );

    expect(beefReady.scorePercent, 95);
    expect(beefReady.missingIngredients, isEmpty);
    expect(beefReady.missingOptionalIngredients, hasLength(1));
    expect(garnishOnly.scorePercent, 5);
    expect(garnishOnly.missingIngredients.single.canonicalIngredientId, 'beef');
  });

  test('partial quantity contributes proportionally to readiness', () {
    final readiness = service.evaluate(
      recipe: _recipe(optional: false),
      pantry: <Ingredient>[_pantry('beef', 0.5, 'kilogram', now)],
      servings: 2,
      evaluatedAt: now,
    );

    expect(readiness.score, closeTo(0.5, 0.000001));
    expect(
      readiness.ingredients.single.status,
      RecipeIngredientReadinessStatus.insufficient,
    );
    expect(readiness.ingredients.single.shortageQuantity, 0.5);
  });

  test('convertible Pantry units are aggregated before scoring', () {
    final recipe = Recipe(
      id: 'soup',
      name: 'Soup',
      category: 'test',
      servings: 1,
      heroIngredientId: 'water',
      ingredients: const <RecipeIngredient>[
        RecipeIngredient(
          id: 'water',
          name: 'Water',
          quantity: 1,
          unit: 'liter',
        ),
      ],
      steps: const <String>[],
    );
    final readiness = service.evaluate(
      recipe: recipe,
      pantry: <Ingredient>[
        _pantry('water', 400, 'milliliter', now),
        _pantry('water', 0.6, 'liter', now, id: 'water-2'),
      ],
      servings: 1,
      evaluatedAt: now,
    );

    expect(readiness.scorePercent, 100);
    expect(readiness.availableIngredients, hasLength(1));
    expect(readiness.ingredients.single.availableQuantity, closeTo(1, 0.000001));
  });

  test('localized name fallback resolves legacy Recipe identity', () {
    const recipe = Recipe(
      id: 'legacy-beef',
      name: 'Legacy Beef',
      category: 'test',
      servings: 1,
      heroIngredientId: 'legacy-beef-key',
      ingredients: <RecipeIngredient>[
        RecipeIngredient(
          id: 'legacy-beef-key',
          name: 'เนื้อวัว',
          quantity: 1,
          unit: 'kilogram',
        ),
      ],
      steps: <String>[],
    );
    final readiness = service.evaluate(
      recipe: recipe,
      pantry: <Ingredient>[_pantry('beef', 1, 'kilogram', now)],
      servings: 1,
      evaluatedAt: now,
    );

    expect(readiness.scorePercent, 100);
    expect(readiness.ingredients.single.canonicalIngredientId, 'beef');
  });

  test('parent and child identities are not treated as substitution', () {
    const recipe = Recipe(
      id: 'beef-dish',
      name: 'Beef Dish',
      category: 'test',
      servings: 1,
      heroIngredientId: 'beef',
      ingredients: <RecipeIngredient>[
        RecipeIngredient(
          id: 'beef',
          name: 'Beef',
          quantity: 1,
          unit: 'kilogram',
        ),
      ],
      steps: <String>[],
    );
    final readiness = service.evaluate(
      recipe: recipe,
      pantry: <Ingredient>[_pantry('beef_slice', 1, 'kilogram', now)],
      servings: 1,
      evaluatedAt: now,
    );

    expect(readiness.scorePercent, 0);
    expect(readiness.missingIngredients, hasLength(1));
  });

  test('expired inventory does not contribute to readiness', () {
    final readiness = service.evaluate(
      recipe: _recipe(optional: false),
      pantry: <Ingredient>[
        _pantry(
          'beef',
          1,
          'kilogram',
          now,
          expiryDate: now.subtract(const Duration(days: 1)),
        ),
      ],
      servings: 2,
      evaluatedAt: now,
    );

    expect(readiness.scorePercent, 0);
    expect(readiness.missingIngredients, hasLength(1));
  });
}

Recipe _recipe({bool optional = true}) {
  return Recipe(
    id: 'black-pepper-beef',
    name: 'Black Pepper Beef',
    category: 'test',
    servings: 2,
    heroIngredientId: 'beef',
    ingredients: <RecipeIngredient>[
      const RecipeIngredient(
        id: 'beef',
        name: 'Beef',
        quantity: 1,
        unit: 'kilogram',
      ),
      if (optional)
        const RecipeIngredient(
          id: 'pepper',
          name: 'Pepper',
          quantity: 1,
          unit: 'piece',
          required: false,
          importance: RecipeIngredientImportance.garnish,
        ),
    ],
    steps: const <String>[],
  );
}

Ingredient _pantry(
  String canonicalId,
  double quantity,
  String unit,
  DateTime now, {
  String? id,
  DateTime? expiryDate,
}) {
  return Ingredient(
    id: id ?? '$canonicalId-lot',
    name: canonicalId,
    category: 'test',
    emoji: '',
    quantity: quantity,
    unit: unit,
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: canonicalId,
    canonicalUnitId: unit,
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

final CanonicalIngredientRegistry _registry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
    _canonical(
      'beef',
      'kilogram',
      localizedName: 'เนื้อวัว',
      aliases: const <String>['beef steak'],
    ),
    _canonical('beef_slice', 'kilogram', parentId: 'beef'),
    _canonical('pepper', 'piece'),
    _canonical('water', 'liter'),
  ],
);

CanonicalIngredient _canonical(
  String id,
  String unit, {
  String? localizedName,
  List<String> aliases = const <String>[],
  String? parentId,
}) {
  return CanonicalIngredient(
    id: id,
    canonicalName: id,
    localizedNames: <String, String>{'th': localizedName ?? id},
    aliases: aliases,
    searchKeywords: const <String>[],
    category: 'test',
    defaultStorageType: IngredientStorageType.pantry,
    defaultPurchaseUnitId: unit,
    defaultInventoryUnitId: unit,
    parentId: parentId,
  );
}
