import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_compatibility.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/main_ingredient_compatibility_service.dart';

void main() {
  const service = MainIngredientCompatibilityService();
  const selection = MainIngredientSelection(
    canonicalIngredientId: 'mackerel',
    displayName: 'ปลาทู',
    cookingMethods: <String>['ทอด', 'ย่าง', 'ต้ม'],
  );

  test('exact recipe remains eligible for its declared cooking method', () {
    const recipe = Recipe(
      id: 'mackerel-mix',
      name: 'ข้าวคลุกน้ำพริกปลาทู',
      category: 'อาหารไทย',
      heroIngredientId: 'mackerel',
      cookingMethods: <String>['คลุก'],
      ingredients: <RecipeIngredient>[
        RecipeIngredient(
          id: 'mackerel',
          name: 'ปลาทู',
          quantity: 1,
          unit: 'ตัว',
          role: RecipeIngredientRole.primary,
        ),
      ],
      steps: <String>['คลุกส่วนผสม'],
    );

    final result = service.evaluate(recipe: recipe, selection: selection);

    expect(result.isEligible, isTrue);
    expect(result.tier, MainIngredientMatchTier.exact);
  });

  test('extended compatibility still respects cooking-method profile', () {
    const recipe = Recipe(
      id: 'generic-baked-fish',
      name: 'ปลาอบสมุนไพร',
      category: 'อาหารไทย',
      heroIngredientId: 'fish',
      cookingMethods: <String>['อบ'],
      compatibility: RecipeCompatibilityMetadata(
        compatibleIngredientIds: <String>['mackerel'],
      ),
      ingredients: <RecipeIngredient>[
        RecipeIngredient(
          id: 'fish',
          name: 'ปลา',
          quantity: 1,
          unit: 'ตัว',
          role: RecipeIngredientRole.primary,
        ),
      ],
      steps: <String>['อบปลา'],
    );

    final result = service.evaluate(recipe: recipe, selection: selection);

    expect(result.isEligible, isFalse);
    expect(
      result.exclusionReason,
      MainIngredientExclusionReason.incompatibleCookingMethod,
    );
  });
}
