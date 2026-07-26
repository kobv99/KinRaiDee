import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart' as pantry_model;
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/recipe_matcher.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

void main() {
  group('SmartRecommendationEngine', () {
    final now = DateTime(2026, 7, 24, 12);
    final pantry = <pantry_model.Ingredient>[
      _pantryIngredient(
        id: 'egg-pantry',
        name: 'ไข่ไก่',
        emoji: '🥚',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      _pantryIngredient(
        id: 'shrimp-pantry',
        name: 'กุ้งขาว',
        emoji: '🦐',
        createdAt: now,
      ),
    ];
    final recipes = <Recipe>[
      ...List<Recipe>.generate(
        6,
        (index) => _recipe(
          id: 'shrimp_$index',
          name: 'เมนูกุ้ง $index',
          heroId: 'shrimp',
          heroName: 'กุ้ง',
          aliases: const <String>['กุ้งขาว', 'กุ้งสด'],
        ),
      ),
      ...List<Recipe>.generate(
        2,
        (index) => _recipe(
          id: 'egg_$index',
          name: 'เมนูไข่ $index',
          heroId: 'egg',
          heroName: 'ไข่ไก่',
          aliases: const <String>['ไข่'],
        ),
      ),
    ];
    final matches = const RecipeMatcher().match(
      recipes: recipes,
      pantry: pantry,
    );

    test('uses the newest relevant pantry ingredient as hero', () {
      final result = const SmartRecommendationEngine().build(
        matches: matches,
        pantry: pantry,
      );

      expect(result.hero?.name, 'กุ้งขาว');
      expect(result.totalHeroRecipes, 6);
      expect(result.primaryMatches, hasLength(5));
      expect(
        result.primaryMatches.every(
          (match) => match.recipe.resolvedHeroIngredientId == 'shrimp',
        ),
        isTrue,
      );
      expect(result.moreMatches, hasLength(2));
      expect(
        result.moreMatches.every(
          (match) => match.recipe.resolvedHeroIngredientId == 'egg',
        ),
        isTrue,
      );
    });

    test('returns the next page without repeating the first page', () {
      const engine = SmartRecommendationEngine();
      final firstPage = engine.build(matches: matches, pantry: pantry);
      final secondPage = engine.build(
        matches: matches,
        pantry: pantry,
        pageIndex: 1,
      );
      final firstIds = firstPage.primaryMatches
          .map((match) => match.recipe.id)
          .toSet();
      final secondIds = secondPage.primaryMatches
          .map((match) => match.recipe.id)
          .toSet();

      expect(secondPage.primaryMatches, hasLength(1));
      expect(firstIds.intersection(secondIds), isEmpty);
    });

    test('reshuffles the pool after a completed recommendation cycle', () {
      const engine = SmartRecommendationEngine();
      final firstCycle = engine.build(
        matches: matches,
        pantry: pantry,
        shuffleSeed: 0,
      );
      final nextCycle = engine.build(
        matches: matches,
        pantry: pantry,
        shuffleSeed: 1,
      );
      final firstIds = firstCycle.primaryMatches
          .map((match) => match.recipe.id)
          .toList(growable: false);
      final nextIds = nextCycle.primaryMatches
          .map((match) => match.recipe.id)
          .toList(growable: false);

      expect(nextIds, isNot(equals(firstIds)));
    });

    test('allows the user to override the selected hero ingredient', () {
      final initial = const SmartRecommendationEngine().build(
        matches: matches,
        pantry: pantry,
      );
      final eggOption = initial.heroOptions.firstWhere(
        (option) => option.name == 'ไข่ไก่',
      );
      final result = const SmartRecommendationEngine().build(
        matches: matches,
        pantry: pantry,
        selectedHeroKey: eggOption.key,
      );

      expect(result.hero?.name, 'ไข่ไก่');
      expect(result.totalHeroRecipes, 2);
      expect(
        result.primaryMatches.every(
          (match) => match.recipe.resolvedHeroIngredientId == 'egg',
        ),
        isTrue,
      );
    });
  });
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
    unit: 'แพ็ก',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Recipe _recipe({
  required String id,
  required String name,
  required String heroId,
  required String heroName,
  required List<String> aliases,
}) {
  return Recipe(
    id: id,
    name: name,
    category: 'อาหารไทย',
    heroIngredientId: heroId,
    heroIngredientName: heroName,
    popularity: 80,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: heroId,
        name: heroName,
        quantity: 1,
        unit: 'ส่วน',
        aliases: aliases,
      ),
      const RecipeIngredient(
        id: 'garlic',
        name: 'กระเทียม',
        quantity: 2,
        unit: 'กลีบ',
      ),
    ],
    steps: const <String>['ทำให้สุก'],
  );
}
