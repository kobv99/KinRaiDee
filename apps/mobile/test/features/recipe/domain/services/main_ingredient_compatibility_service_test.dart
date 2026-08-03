import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_compatibility.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_match.dart';
import 'package:mobile/features/recipe/domain/services/main_ingredient_compatibility_service.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

void main() {
  group('MainIngredientCompatibilityService', () {
    const selection = MainIngredientSelection(
      canonicalIngredientId: 'mackerel',
      displayName: 'ปลาทู',
      forms: <String>['whole_cleaned'],
      textures: <String>['oily', 'soft'],
      cookingMethods: <String>['fried', 'grilled', 'steamed'],
      familyIds: <String>['fish'],
    );
    const service = MainIngredientCompatibilityService();

    test('uses the deterministic culinary hierarchy', () {
      final cases = <(Recipe, MainIngredientMatchTier)>[
        (
          _recipe(id: 'exact', heroId: 'mackerel'),
          MainIngredientMatchTier.exact,
        ),
        (
          _recipe(
            id: 'preferred',
            heroId: 'fish',
            compatibility: const RecipeCompatibilityMetadata(
              preferredIngredientIds: <String>['mackerel'],
            ),
          ),
          MainIngredientMatchTier.preferred,
        ),
        (
          _recipe(
            id: 'compatible',
            heroId: 'fish',
            compatibility: const RecipeCompatibilityMetadata(
              compatibleIngredientIds: <String>['mackerel'],
            ),
          ),
          MainIngredientMatchTier.compatible,
        ),
        (
          _recipe(
            id: 'substitute',
            heroId: 'fish',
            compatibility: const RecipeCompatibilityMetadata(
              substituteIngredientIds: <String>['mackerel'],
            ),
          ),
          MainIngredientMatchTier.substitute,
        ),
        (
          _recipe(
            id: 'family',
            heroId: 'white_fish',
            compatibility: const RecipeCompatibilityMetadata(
              ingredientFamilyIds: <String>['fish'],
            ),
          ),
          MainIngredientMatchTier.family,
        ),
      ];

      for (final (recipe, expectedTier) in cases) {
        final result = service.evaluate(recipe: recipe, selection: selection);
        expect(result.isEligible, isTrue, reason: recipe.id);
        expect(result.tier, expectedTier, reason: recipe.id);
        expect(result.reason, isNot(contains(expectedTier.name)));
      }
    });

    test('explicit exclusion wins even over an exact ingredient', () {
      final result = service.evaluate(
        recipe: _recipe(
          id: 'excluded',
          heroId: 'mackerel',
          compatibility: const RecipeCompatibilityMetadata(
            excludedIngredientIds: <String>['mackerel'],
          ),
        ),
        selection: selection,
      );

      expect(result.isEligible, isFalse);
      expect(
        result.exclusionReason,
        MainIngredientExclusionReason.explicitlyExcluded,
      );
    });

    test('required boneless fillet excludes whole mackerel', () {
      final result = service.evaluate(
        recipe: _recipe(
          id: 'fillet-only',
          heroId: 'fish',
          compatibility: const RecipeCompatibilityMetadata(
            compatibleIngredientIds: <String>['mackerel'],
            requiredIngredientForms: <String>['boneless_fillet'],
          ),
        ),
        selection: selection,
      );

      expect(result.isEligible, isFalse);
      expect(
        result.exclusionReason,
        MainIngredientExclusionReason.incompatibleForm,
      );
    });

    test('texture and cooking method constraints are hard gates', () {
      final firmTexture = service.evaluate(
        recipe: _recipe(
          id: 'firm-only',
          heroId: 'fish',
          compatibility: const RecipeCompatibilityMetadata(
            compatibleIngredientIds: <String>['mackerel'],
            requiredTexture: 'firm',
          ),
        ),
        selection: selection,
      );
      final poachedOnly = service.evaluate(
        recipe: _recipe(
          id: 'poached-only',
          heroId: 'fish',
          methods: const <String>['poached'],
          compatibility: const RecipeCompatibilityMetadata(
            compatibleIngredientIds: <String>['mackerel'],
          ),
        ),
        selection: selection,
      );

      expect(
        firmTexture.exclusionReason,
        MainIngredientExclusionReason.incompatibleTexture,
      );
      expect(
        poachedOnly.exclusionReason,
        MainIngredientExclusionReason.incompatibleCookingMethod,
      );
    });

    test('does not infer a family match without an explicit profile', () {
      final result = service.evaluate(
        recipe: _recipe(
          id: 'family',
          heroId: 'white_fish',
          compatibility: const RecipeCompatibilityMetadata(
            ingredientFamilyIds: <String>['fish'],
          ),
        ),
        selection: const MainIngredientSelection(
          canonicalIngredientId: 'mackerel',
          displayName: 'ปลาทู',
        ),
      );

      expect(result.isEligible, isFalse);
      expect(
        result.exclusionReason,
        MainIngredientExclusionReason.unverifiedFamily,
      );
    });
  });

  test(
    'SmartRecommendationEngine ranks compatibility before Pantry readiness',
    () {
      final now = DateTime.utc(2026, 8, 1);
      final pantry = <Ingredient>[
        Ingredient(
          id: 'mackerel-lot',
          name: 'ปลาทู',
          category: 'seafood',
          emoji: '🐟',
          quantity: 2,
          unit: 'whole',
          canonicalIngredientId: 'mackerel',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final matches = <RecipeMatch>[
        _match(
          _recipe(
            id: 'compatible-high',
            heroId: 'fish',
            compatibility: const RecipeCompatibilityMetadata(
              compatibleIngredientIds: <String>['mackerel'],
            ),
          ),
          score: 1,
        ),
        _match(_recipe(id: 'exact-low', heroId: 'mackerel'), score: 0.4),
        _match(
          _recipe(
            id: 'substitute-high',
            heroId: 'fish',
            compatibility: const RecipeCompatibilityMetadata(
              substituteIngredientIds: <String>['mackerel'],
            ),
          ),
          score: 1,
        ),
        _match(
          _recipe(
            id: 'family-high',
            heroId: 'white_fish',
            compatibility: const RecipeCompatibilityMetadata(
              ingredientFamilyIds: <String>['fish'],
            ),
          ),
          score: 1,
        ),
        _match(_recipe(id: 'unverified-high', heroId: 'fish'), score: 1),
      ];
      const engine = SmartRecommendationEngine(
        pageSize: 10,
        compatibilityService: MainIngredientCompatibilityService(
          config: MainIngredientCompatibilityConfig(
            profiles: <String, IngredientCompatibilityProfile>{
              'mackerel': IngredientCompatibilityProfile(
                forms: <String>['whole'],
                familyIds: <String>['fish'],
              ),
            },
          ),
        ),
      );

      final result = engine.build(matches: matches, pantry: pantry);

      expect(result.primaryMatches.map((match) => match.recipe.id), <String>[
        'exact-low',
        'compatible-high',
        'substitute-high',
      ]);
      expect(result.adaptableMatches.map((match) => match.recipe.id), <String>[
        'family-high',
      ]);
      expect(<String>{
        ...result.primaryMatches.map((match) => match.recipe.id),
        ...result.adaptableMatches.map((match) => match.recipe.id),
      }, isNot(contains('unverified-high')));
      expect(result.primaryMatches.first.matchReason, 'ตรงกับปลาทูโดยตรง');
    },
  );

  test('manual selection can be evaluated without a Pantry lot', () {
    final result = const SmartRecommendationEngine().build(
      matches: <RecipeMatch>[
        RecipeMatch(
          recipe: Recipe(
            id: 'mackerel-salad',
            name: 'ยำปลาทู',
            category: 'test',
            heroIngredientId: 'mackerel',
            ingredients: <RecipeIngredient>[
              RecipeIngredient(
                id: 'mackerel',
                name: 'ปลาทู',
                quantity: 1,
                unit: 'whole',
                role: RecipeIngredientRole.primary,
              ),
            ],
            steps: <String>['cook'],
          ),
          matchedIngredients: <RecipeIngredient>[],
          missingIngredients: <RecipeIngredient>[],
          score: 0,
        ),
      ],
      pantry: const <Ingredient>[],
      selectedIngredient: const MainIngredientSelection(
        canonicalIngredientId: 'mackerel',
        displayName: 'ปลาทู',
        emoji: '🐟',
      ),
    );

    expect(result.requestedSelectionAvailable, isTrue);
    expect(result.hero?.key, 'mackerel');
    expect(result.primaryMatches.single.recipe.id, 'mackerel-salad');
  });
}

Recipe _recipe({
  required String id,
  required String heroId,
  RecipeCompatibilityMetadata compatibility =
      const RecipeCompatibilityMetadata(),
  List<String> methods = const <String>[],
}) {
  return Recipe(
    id: id,
    name: id,
    category: 'test',
    heroIngredientId: heroId,
    heroIngredientName: heroId,
    compatibility: compatibility,
    cookingMethods: methods,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: heroId,
        name: heroId,
        quantity: 1,
        unit: 'portion',
        role: RecipeIngredientRole.primary,
      ),
    ],
    steps: const <String>['cook'],
  );
}

RecipeMatch _match(Recipe recipe, {required double score}) {
  return RecipeMatch(
    recipe: recipe,
    matchedIngredients: const <RecipeIngredient>[],
    missingIngredients: const <RecipeIngredient>[],
    score: score,
  );
}
