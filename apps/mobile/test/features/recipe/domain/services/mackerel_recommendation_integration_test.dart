import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_compatibility.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_match.dart';
import 'package:mobile/features/recipe/domain/services/main_ingredient_compatibility_service.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real mackerel recipes rank before verified generic fish recipes', () async {
    final recipes = await const LocalRecipeDataSource().loadRecipes();
    final registry = await IngredientCatalog().loadRegistry();
    final service = MainIngredientCompatibilityService(
      config: MainIngredientCompatibilityConfig(
        profiles: <String, IngredientCompatibilityProfile>{
          for (final ingredient in registry.ingredients)
            ingredient.id: IngredientCompatibilityProfile(
              forms: ingredient.ingredientForms,
              textures: ingredient.textures,
              cookingMethods: ingredient.supportedCookingMethods,
              familyIds: registry
                  .ancestorIdsFor(ingredient.id)
                  .toList(growable: false),
            ),
        },
      ),
    );
    final matches = recipes
        .map(
          (recipe) => RecipeMatch(
            recipe: recipe,
            matchedIngredients: const [],
            missingIngredients: const [],
            score: 0.5,
          ),
        )
        .toList(growable: false);
    final engine = SmartRecommendationEngine(
      pageSize: 50,
      compatibilityService: service,
    );

    final result = engine.build(
      matches: matches,
      allRecipeMatches: matches,
      pantry: const [],
      registry: registry,
      selectedIngredient: const MainIngredientSelection(
        canonicalIngredientId: 'mackerel',
        displayName: 'ปลาทู',
        emoji: '🐟',
      ),
    );

    final ranked = result.primaryMatches;
    final exactMackerel = ranked
        .where((match) => match.mainIngredientMatchTier == MainIngredientMatchTier.exact)
        .toList(growable: false);

    expect(exactMackerel, hasLength(7));
    expect(
      ranked.take(7).every(
        (match) => match.recipe.resolvedHeroIngredientId == 'mackerel',
      ),
      isTrue,
    );
    expect(
      ranked.map((match) => match.recipe.id),
      isNot(contains('fish_14')),
      reason: 'ปลาผัดพริกไทยดำไม่ได้ยืนยันว่ารองรับปลาทู',
    );
    expect(
      ranked.map((match) => match.recipe.id),
      isNot(contains('fish_10')),
      reason: 'แกงส้มปลาไม่ได้ยืนยันว่ารองรับปลาทู',
    );
    expect(result.hero?.key, 'mackerel');
    expect(result.hero?.name, 'ปลาทู');
  });
}
