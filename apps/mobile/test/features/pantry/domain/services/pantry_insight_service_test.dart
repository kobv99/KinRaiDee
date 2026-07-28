import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/domain/services/pantry_insight_service.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/recipe_readiness_service.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_recommendation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('summarizes ready, almost-ready, missing, and recommendations', () async {
    final now = DateTime.utc(2026, 7, 29, 8);
    final registry = await IngredientCatalog().loadRegistry();
    final readinessService = RecipeReadinessService(
      registry: registry,
      unitEngine: UnitConversionEngine.standard(),
    );
    final service = PantryInsightService(
      readinessService: readinessService,
      registry: registry,
    );

    final recipes = <Recipe>[
      const Recipe(
        id: 'ready',
        name: 'ไข่เจียว',
        category: 'test',
        servings: 1,
        ingredients: <RecipeIngredient>[
          RecipeIngredient(
            id: 'egg',
            name: 'ไข่ไก่',
            quantity: 1,
            unit: 'ฟอง',
            role: RecipeIngredientRole.primary,
          ),
        ],
        steps: <String>['cook'],
      ),
      const Recipe(
        id: 'almost',
        name: 'ไข่ผัดหอม',
        category: 'test',
        servings: 1,
        ingredients: <RecipeIngredient>[
          RecipeIngredient(
            id: 'egg',
            name: 'ไข่ไก่',
            quantity: 1,
            unit: 'ฟอง',
            role: RecipeIngredientRole.primary,
          ),
          RecipeIngredient(
            id: 'onion',
            name: 'หอมหัวใหญ่',
            quantity: 1,
            unit: 'หัว',
            role: RecipeIngredientRole.secondary,
          ),
        ],
        steps: <String>['cook'],
      ),
      const Recipe(
        id: 'not-ready',
        name: 'กระเทียมหอม',
        category: 'test',
        servings: 1,
        ingredients: <RecipeIngredient>[
          RecipeIngredient(
            id: 'garlic',
            name: 'กระเทียม',
            quantity: 2,
            unit: 'กลีบ',
            role: RecipeIngredientRole.primary,
          ),
          RecipeIngredient(
            id: 'onion',
            name: 'หอมหัวใหญ่',
            quantity: 1,
            unit: 'หัว',
            role: RecipeIngredientRole.secondary,
          ),
        ],
        steps: <String>['cook'],
      ),
    ];

    final pantry = <Ingredient>[
      Ingredient(
        id: 'egg-lot',
        name: 'ไข่ไก่',
        category: 'ไข่',
        emoji: '🥚',
        quantity: 6,
        unit: 'ฟอง',
        createdAt: now,
        updatedAt: now,
        canonicalIngredientId: 'egg',
        canonicalUnitId: 'egg',
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    ];

    final recommendations = <ShoppingRecommendation>[
      ShoppingRecommendation(
        canonicalIngredientId: 'onion',
        displayName: 'หอมหัวใหญ่',
        emoji: '🧅',
        recommendedQuantity: 1,
        targetShoppingQuantity: 1,
        existingShoppingQuantity: 0,
        recommendedUnitId: 'piece',
        score: 100,
        evidence: RecommendationEvidence(
          impactedRecipeCount: 2,
          recipesUnlocked: 1,
          averageReadinessBefore: 0.5,
          averageReadinessAfter: 0.9,
          averageReadinessIncrease: 0.4,
          totalReadinessIncrease: 0.8,
          primaryRecipeCount: 0,
          secondaryRecipeCount: 2,
          ingredientFrequency: 2,
          reasonCodes: const <RecommendationReasonCode>[
            RecommendationReasonCode.improvesNearlyReadyRecipes,
          ],
        ),
        topRecipes: const <RecommendationRecipeImpact>[],
      ),
    ];

    final insight = service.analyze(
      pantry: pantry,
      recipes: recipes,
      recommendations: recommendations,
      evaluatedAt: now,
    );

    expect(insight.ingredientCount, 1);
    expect(insight.availableRecipeCount, 1);
    expect(insight.almostReadyRecipeCount, 1);
    expect(insight.missingIngredientCount, 2);
    expect(insight.recommendationCount, 1);
    expect(insight.topRecommendationName, 'หอมหัวใหญ่');
    expect(insight.topRecommendationRecipesUnlocked, 1);
  });
}
