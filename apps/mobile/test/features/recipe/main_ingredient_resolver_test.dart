import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart' as pantry_model;
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/smart_recommendation.dart';
import 'package:mobile/features/recipe/domain/services/main_ingredient_resolver.dart';
import 'package:mobile/features/recipe/domain/services/recipe_matcher.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

void main() {
  group('MainIngredientResolver', () {
    test('maps a pork cut in Pantry to the pork recipe family', () {
      final resolution = const MainIngredientResolver().resolve(
        pantryIngredientName: 'สันคอหมู',
        recipes: <Recipe>[
          _recipe(
            id: 'pork_grill',
            heroId: 'pork',
            heroName: 'หมู',
            aliases: const <String>['เนื้อหมู', 'หมูสด'],
          ),
          _recipe(
            id: 'pork_basil',
            heroId: 'pork',
            heroName: 'หมู',
            aliases: const <String>['เนื้อหมู', 'หมูสด'],
          ),
        ],
      );

      expect(resolution?.key, 'pork');
      expect(resolution?.recipeCount, 2);
    });

    test('returns null when no recipe family supports the Pantry item', () {
      final resolution = const MainIngredientResolver().resolve(
        pantryIngredientName: 'อะโวคาโด',
        recipes: <Recipe>[
          _recipe(
            id: 'egg_omelette',
            heroId: 'egg',
            heroName: 'ไข่ไก่',
            aliases: const <String>['ไข่'],
          ),
        ],
      );

      expect(resolution, isNull);
    });
  });

  test('manual selection reason from Pantry is shown on recommendations', () {
    final now = DateTime(2026, 7, 24, 12);
    final pantry = <pantry_model.Ingredient>[
      pantry_model.Ingredient(
        id: 'pork-neck',
        name: 'สันคอหมู',
        category: 'เนื้อสัตว์',
        emoji: '🐷',
        quantity: 500,
        unit: 'กรัม',
        expiryDate: DateTime(2026, 7, 25),
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final recipes = <Recipe>[
      _recipe(
        id: 'pork_grill',
        heroId: 'pork',
        heroName: 'หมู',
        aliases: const <String>['เนื้อหมู', 'หมูสด'],
      ),
    ];
    final matches = const RecipeMatcher().match(
      recipes: recipes,
      pantry: pantry,
    );
    final result = const SmartRecommendationEngine().build(
      matches: matches,
      pantry: pantry,
      selectedHeroKey: 'pork',
      selectionMode: HeroSelectionMode.manual,
      selectionReason: 'เลือกจาก Pantry เพราะ สันคอหมู หมดอายุพรุ่งนี้',
    );

    expect(result.hero?.key, 'pork');
    expect(
      result.heroReason,
      'เลือกจาก Pantry เพราะ สันคอหมู หมดอายุพรุ่งนี้',
    );
  });
}

Recipe _recipe({
  required String id,
  required String heroId,
  required String heroName,
  required List<String> aliases,
}) {
  return Recipe(
    id: id,
    name: id,
    category: 'อาหารไทย',
    servings: 2,
    heroIngredientId: heroId,
    heroIngredientName: heroName,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: heroId,
        name: heroName,
        quantity: 200,
        unit: 'กรัม',
        aliases: aliases,
      ),
    ],
    steps: const <String>['ทำให้สุก'],
  );
}