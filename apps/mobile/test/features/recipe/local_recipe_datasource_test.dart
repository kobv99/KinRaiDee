import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the complete local recipe database without duplicate ids',
    () async {
      final recipes = await const LocalRecipeDataSource().loadRecipes();
      final ids = recipes.map((recipe) => recipe.id).toSet();
      final shrimpRecipes = recipes
          .where((recipe) => recipe.resolvedHeroIngredientId == 'shrimp')
          .toList(growable: false);
      final beefRecipes = recipes
          .where((recipe) => recipe.resolvedHeroIngredientId == 'beef')
          .toList(growable: false);
      final fishRecipes = recipes
          .where((recipe) => recipe.resolvedHeroIngredientId == 'fish')
          .toList(growable: false);
      final saltedEggRecipes = recipes
          .where((recipe) => recipe.resolvedHeroIngredientId == 'salted_egg')
          .toList(growable: false);
      final rawRiceRecipes = recipes
          .where((recipe) => recipe.resolvedHeroIngredientId == 'raw_rice')
          .toList(growable: false);

      expect(recipes.length, greaterThanOrEqualTo(158));
      expect(ids.length, recipes.length);
      expect(shrimpRecipes, hasLength(20));
      expect(beefRecipes, hasLength(20));
      expect(fishRecipes, hasLength(20));
      expect(saltedEggRecipes, hasLength(12));
      expect(
        rawRiceRecipes.map((recipe) => recipe.id),
        containsAll(<String>[
          'raw_rice_egg_fried_rice',
          'raw_rice_garlic_pork_bowl',
          'raw_rice_porridge',
        ]),
        reason: 'Raw rice must unlock recipes that start from uncooked rice',
      );
      for (final recipe in rawRiceRecipes) {
        expect(
          recipe.ingredients.any(
            (ingredient) =>
                ingredient.canonicalIngredientId == 'raw_rice' &&
                ingredient.role == RecipeIngredientRole.primary,
          ),
          isTrue,
          reason: '${recipe.id} must declare raw_rice as a Primary ingredient',
        );
      }
      for (final canonicalId in <String>[
        'raw_rice',
        'rice',
        'mackerel',
        'tilapia',
        'sea_bass',
        'salmon',
        'shallot',
        'coriander',
        'palm_sugar',
      ]) {
        expect(
          recipes.where(
            (recipe) => recipe.ingredients.any(
              (ingredient) => ingredient.canonicalIngredientId == canonicalId,
            ),
          ),
          isNotEmpty,
          reason: '$canonicalId must participate in at least one Recipe',
        );
      }
      expect(
        recipes
            .where((recipe) => recipe.resolvedHeroIngredientId == 'sea_bass')
            .length,
        greaterThanOrEqualTo(3),
      );
      expect(
        recipes
            .singleWhere((recipe) => recipe.id == 'steamed_rice')
            .supportsSubstitutions,
        isFalse,
      );
      expect(
        recipes.where((recipe) => recipe.instructions.length > 3).length,
        greaterThan(150),
        reason: 'Recipe packs must not be forced into a three-step template',
      );
      expect(
        recipes
            .where((recipe) => recipe.detailedSteps.isNotEmpty)
            .expand((recipe) => recipe.instructions)
            .every(
              (step) =>
                  step.title.trim().isNotEmpty &&
                  step.instruction.trim().isNotEmpty &&
                  step.completionCue?.trim().isNotEmpty == true,
            ),
        isTrue,
      );
    },
  );

  test(
    'every local recipe has quantities suitable for serving scaling',
    () async {
      final recipes = await const LocalRecipeDataSource().loadRecipes();

      for (final recipe in recipes) {
        expect(
          recipe.servings,
          greaterThan(0),
          reason: '${recipe.id} must define positive base servings',
        );
        expect(
          recipe.ingredients,
          isNotEmpty,
          reason: '${recipe.id} must contain ingredients',
        );

        for (final ingredient in recipe.ingredients) {
          expect(
            ingredient.quantity,
            greaterThan(0),
            reason: '${recipe.id}/${ingredient.id} must have positive quantity',
          );
          expect(
            ingredient.unit.trim(),
            isNotEmpty,
            reason: '${recipe.id}/${ingredient.id} must define a unit',
          );
          if (recipe.version >= 2) {
            expect(
              ingredient.role,
              isNotNull,
              reason:
                  '${recipe.id}/${ingredient.id} must declare a role in v2 data',
            );
          }
        }
        expect(
          recipe.steps.length,
          greaterThanOrEqualTo(2),
          reason: '${recipe.id} must contain actionable instructions',
        );
        for (final step in recipe.steps) {
          expect(
            step.trim().length,
            greaterThanOrEqualTo(12),
            reason: '${recipe.id} has an instruction that is too vague',
          );
        }
      }
    },
  );
}
