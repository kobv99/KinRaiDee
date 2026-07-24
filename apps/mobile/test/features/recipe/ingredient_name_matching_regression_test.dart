import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart' as pantry_model;
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/ingredient_name_matcher.dart';
import 'package:mobile/features/recipe/domain/services/recipe_matcher.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

void main() {
  const chickenIngredient = RecipeIngredient(
    id: 'chicken',
    name: 'ไก่',
    quantity: 200,
    unit: 'กรัม',
    aliases: <String>['เนื้อไก่', 'ไก่สด', 'อกไก่'],
  );
  const shrimpIngredient = RecipeIngredient(
    id: 'shrimp',
    name: 'กุ้ง',
    quantity: 200,
    unit: 'กรัม',
    aliases: <String>['กุ้งสด', 'กุ้งขาว'],
  );

  test('exact alias matching does not confuse ไข่ไก่ with ไก่', () {
    expect(
      recipeIngredientMatchesPantryName(chickenIngredient, 'ไข่ไก่'),
      isFalse,
    );
    expect(
      recipeIngredientMatchesPantryName(chickenIngredient, 'เนื้อไก่'),
      isTrue,
    );
    expect(
      recipeIngredientMatchesPantryName(shrimpIngredient, 'กุ้งขาว'),
      isTrue,
    );
  });

  test('RecipeMatcher does not mark chicken as owned from an egg pantry item', () {
    final pantry = <pantry_model.Ingredient>[_eggPantryIngredient()];
    final matches = const RecipeMatcher().match(
      recipes: <Recipe>[_eggRecipe(), _chickenRecipe()],
      pantry: pantry,
    );
    final chickenMatch = matches.firstWhere(
      (match) => match.recipe.id == 'chicken_cashew',
    );

    expect(chickenMatch.matchedIngredients, isEmpty);
    expect(chickenMatch.scorePercent, 0);
    expect(chickenMatch.canCook, isFalse);
  });

  test('egg hero recommendations never include chicken recipes', () {
    final pantry = <pantry_model.Ingredient>[_eggPantryIngredient()];
    final matches = const RecipeMatcher().match(
      recipes: <Recipe>[_eggRecipe(), _chickenRecipe()],
      pantry: pantry,
    );
    final result = const SmartRecommendationEngine().build(
      matches: matches,
      pantry: pantry,
    );

    expect(result.hero?.key, 'egg');
    expect(result.totalHeroRecipes, 1);
    expect(
      result.primaryMatches.map((match) => match.recipe.id),
      <String>['egg_omelette'],
    );
    expect(
      result.moreMatches.any((match) => match.recipe.id == 'chicken_cashew'),
      isFalse,
    );
  });
}

pantry_model.Ingredient _eggPantryIngredient() {
  final now = DateTime(2026, 7, 24, 20);
  return pantry_model.Ingredient(
    id: 'egg-pantry',
    name: 'ไข่ไก่',
    category: 'protein',
    emoji: '🥚',
    quantity: 6,
    unit: 'ฟอง',
    createdAt: now,
    updatedAt: now,
  );
}

Recipe _eggRecipe() {
  return const Recipe(
    id: 'egg_omelette',
    name: 'ไข่เจียว',
    category: 'อาหารไทย',
    heroIngredientId: 'egg',
    heroIngredientName: 'ไข่ไก่',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'egg',
        name: 'ไข่ไก่',
        quantity: 2,
        unit: 'ฟอง',
        aliases: <String>['ไข่', 'ไข่สด'],
      ),
    ],
    steps: <String>['ทอดไข่ให้สุก'],
  );
}

Recipe _chickenRecipe() {
  return const Recipe(
    id: 'chicken_cashew',
    name: 'ไก่ผัดเม็ดมะม่วง',
    category: 'อาหารไทย',
    heroIngredientId: 'chicken',
    heroIngredientName: 'ไก่',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'chicken',
        name: 'ไก่',
        quantity: 200,
        unit: 'กรัม',
        aliases: <String>['เนื้อไก่', 'ไก่สด', 'อกไก่'],
      ),
    ],
    steps: <String>['ผัดไก่ให้สุก'],
  );
}
