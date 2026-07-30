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
  final now = DateTime.utc(2026, 7, 28, 8);
  final service = RecipeCandidateService(
    readinessService: RecipeReadinessService(
      registry: _registry,
      unitEngine: UnitConversionEngine.standard(),
    ),
  );

  test('Egg alone does not make Pad Kra Pao a recommendation candidate', () {
    final candidates = service.findCandidates(
      recipes: const <Recipe>[_padKraPao],
      pantry: <Ingredient>[_pantry('egg', now)],
      evaluatedAt: now,
    );

    expect(candidates, isEmpty);
  });

  test('either declared Primary ingredient makes the recipe a candidate', () {
    final fromPork = service.findCandidates(
      recipes: const <Recipe>[_padKraPao],
      pantry: <Ingredient>[_pantry('pork', now)],
      evaluatedAt: now,
    );
    final fromBasil = service.findCandidates(
      recipes: const <Recipe>[_padKraPao],
      pantry: <Ingredient>[_pantry('holy_basil', now)],
      evaluatedAt: now,
    );

    expect(fromPork.single.recipe.id, _padKraPao.id);
    expect(fromPork.single.scorePercent, 40);
    expect(fromBasil.single.recipe.id, _padKraPao.id);
    expect(fromBasil.single.scorePercent, 35);
  });

  test('minced pork represents the parent pork candidate', () {
    final candidates = service.findCandidates(
      recipes: const <Recipe>[_padKraPao],
      pantry: <Ingredient>[_pantry('minced_pork', now)],
      evaluatedAt: now,
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.recipe.id, _padKraPao.id);
    expect(candidates.single.scorePercent, 40);
  });

  test('candidate ranking uses data weights rather than ingredient count', () {
    final candidates = service.findCandidates(
      recipes: const <Recipe>[_padKraPao, _eggSnack],
      pantry: <Ingredient>[
        _pantry('pork', now),
        _pantry('egg', now),
        _pantry('garlic', now),
      ],
      evaluatedAt: now,
    );

    expect(
      candidates.map((candidate) => candidate.recipe.id),
      orderedEquals(<String>['pad-kra-pao', 'egg-snack']),
    );
    expect(candidates.first.scorePercent, 55);
    expect(candidates.last.scorePercent, 20);
  });

  test('rice as a declared Primary recommends fried rice', () {
    final candidates = service.findCandidates(
      recipes: const <Recipe>[_friedRice],
      pantry: <Ingredient>[_pantry('rice', now)],
      evaluatedAt: now,
    );

    expect(candidates.single.recipe.id, 'fried-rice');
    expect(candidates.single.matchedPrimaryIngredients, hasLength(1));
  });
}

const Recipe _padKraPao = Recipe(
  id: 'pad-kra-pao',
  name: 'Pad Kra Pao',
  category: 'test',
  servings: 1,
  heroIngredientId: 'pork',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'pork',
      name: 'Pork',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.primary,
      weight: 40,
    ),
    RecipeIngredient(
      id: 'holy_basil',
      name: 'Holy Basil',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.primary,
      weight: 35,
    ),
    RecipeIngredient(
      id: 'garlic',
      name: 'Garlic',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.secondary,
      weight: 10,
    ),
    RecipeIngredient(
      id: 'chili',
      name: 'Chili',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.secondary,
      weight: 10,
    ),
    RecipeIngredient(
      id: 'egg',
      name: 'Fried Egg',
      quantity: 1,
      unit: 'piece',
      required: false,
      role: RecipeIngredientRole.optional,
      weight: 5,
    ),
  ],
  steps: <String>[],
);

const Recipe _eggSnack = Recipe(
  id: 'egg-snack',
  name: 'Egg Snack',
  category: 'test',
  servings: 1,
  heroIngredientId: 'egg',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'egg',
      name: 'Egg',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.primary,
      weight: 20,
    ),
    RecipeIngredient(
      id: 'chili',
      name: 'Chili',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.secondary,
      weight: 80,
    ),
  ],
  steps: <String>[],
);

const Recipe _friedRice = Recipe(
  id: 'fried-rice',
  name: 'Fried Rice',
  category: 'test',
  servings: 1,
  heroIngredientId: 'rice',
  ingredients: <RecipeIngredient>[
    RecipeIngredient(
      id: 'rice',
      name: 'Rice',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.primary,
      weight: 40,
    ),
    RecipeIngredient(
      id: 'egg',
      name: 'Egg',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.secondary,
      weight: 20,
    ),
    RecipeIngredient(
      id: 'soy_sauce',
      name: 'Soy Sauce',
      quantity: 1,
      unit: 'piece',
      role: RecipeIngredientRole.secondary,
      weight: 15,
    ),
  ],
  steps: <String>[],
);

Ingredient _pantry(String canonicalId, DateTime now) {
  return Ingredient(
    id: '$canonicalId-lot',
    name: canonicalId,
    category: 'test',
    emoji: '',
    quantity: 1,
    unit: 'piece',
    createdAt: now,
    updatedAt: now,
    canonicalIngredientId: canonicalId,
    canonicalUnitId: 'piece',
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

final CanonicalIngredientRegistry _registry = CanonicalIngredientRegistry(
  ingredients: <CanonicalIngredient>[
    for (final id in <String>[
      'pork',
      'holy_basil',
      'garlic',
      'chili',
      'egg',
      'rice',
      'soy_sauce',
    ])
      CanonicalIngredient(
        id: id,
        canonicalName: id,
        localizedNames: <String, String>{'th': id},
        aliases: const <String>[],
        searchKeywords: const <String>[],
        category: 'test',
        defaultStorageType: IngredientStorageType.pantry,
        defaultPurchaseUnitId: 'piece',
        defaultInventoryUnitId: 'piece',
      ),
    CanonicalIngredient(
      id: 'minced_pork',
      canonicalName: 'minced pork',
      localizedNames: const <String, String>{'th': 'หมูสับ'},
      aliases: const <String>[],
      searchKeywords: const <String>[],
      category: 'test',
      defaultStorageType: IngredientStorageType.pantry,
      defaultPurchaseUnitId: 'piece',
      defaultInventoryUnitId: 'piece',
      parentId: 'pork',
    ),
  ],
);
