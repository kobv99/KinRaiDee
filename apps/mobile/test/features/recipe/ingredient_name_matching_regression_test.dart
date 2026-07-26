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
  const porkIngredient = RecipeIngredient(
    id: 'pork',
    name: 'หมู',
    quantity: 200,
    unit: 'กรัม',
    aliases: <String>['เนื้อหมู', 'หมูสด'],
  );
  const beefIngredient = RecipeIngredient(
    id: 'beef',
    name: 'เนื้อวัว',
    quantity: 200,
    unit: 'กรัม',
    aliases: <String>['เนื้อ', 'วัว'],
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

  test('common meat cuts resolve to their ingredient family', () {
    expect(
      recipeIngredientMatchesPantryName(porkIngredient, 'สันคอหมู'),
      isTrue,
    );
    expect(
      recipeIngredientMatchesPantryName(porkIngredient, 'หมูสามชั้น'),
      isTrue,
    );
    expect(
      recipeIngredientMatchesPantryName(beefIngredient, 'เนื้อวัว'),
      isTrue,
    );
    expect(
      recipeIngredientMatchesPantryName(beefIngredient, 'เนื้อวัวสไลซ์'),
      isTrue,
    );
  });

  test(
    'RecipeMatcher does not mark chicken as owned from an egg pantry item',
    () {
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
    },
  );

  test('egg main ingredient recommendations never include chicken recipes', () {
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
    expect(result.primaryMatches.map((match) => match.recipe.id), <String>[
      'egg_omelette',
    ]);
    expect(
      result.moreMatches.any((match) => match.recipe.id == 'chicken_cashew'),
      isFalse,
    );
  });

  test('main ingredient picker includes pork neck, egg and beef', () {
    final now = DateTime(2026, 7, 24, 20);
    final pantry = <pantry_model.Ingredient>[
      _pantryIngredient(
        id: 'pork-neck-pantry',
        name: 'สันคอหมู',
        emoji: '🐷',
        createdAt: now,
      ),
      _eggPantryIngredient(),
      _pantryIngredient(
        id: 'beef-pantry',
        name: 'เนื้อวัว',
        emoji: '🥩',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    ];
    final recipes = <Recipe>[_porkRecipe(), _eggRecipe(), _beefRecipe()];
    final matches = const RecipeMatcher().match(
      recipes: recipes,
      pantry: pantry,
    );
    final result = const SmartRecommendationEngine().build(
      matches: matches,
      pantry: pantry,
    );

    expect(
      result.heroOptions.map((option) => option.key).toSet(),
      containsAll(<String>{'pork', 'egg', 'beef'}),
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

pantry_model.Ingredient _pantryIngredient({
  required String id,
  required String name,
  required String emoji,
  required DateTime createdAt,
}) {
  return pantry_model.Ingredient(
    id: id,
    name: name,
    category: 'protein',
    emoji: emoji,
    quantity: 1,
    unit: 'กิโลกรัม',
    createdAt: createdAt,
    updatedAt: createdAt,
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

Recipe _porkRecipe() {
  return const Recipe(
    id: 'pork_garlic',
    name: 'หมูกระเทียม',
    category: 'อาหารไทย',
    heroIngredientId: 'pork',
    heroIngredientName: 'หมู',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'pork',
        name: 'หมู',
        quantity: 200,
        unit: 'กรัม',
        aliases: <String>['เนื้อหมู', 'หมูสด'],
      ),
    ],
    steps: <String>['ผัดหมูให้สุก'],
  );
}

Recipe _beefRecipe() {
  return const Recipe(
    id: 'beef_garlic',
    name: 'เนื้อกระเทียม',
    category: 'อาหารไทย',
    heroIngredientId: 'beef',
    heroIngredientName: 'เนื้อวัว',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: 'beef',
        name: 'เนื้อวัว',
        quantity: 200,
        unit: 'กรัม',
        aliases: <String>['เนื้อ', 'วัว', 'เนื้อวัวสไลซ์'],
      ),
    ],
    steps: <String>['ผัดเนื้อให้สุก'],
  );
}
