import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart' as pantry_model;
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/smart_recommendation.dart';
import 'package:mobile/features/recipe/domain/services/recipe_matcher.dart';
import 'package:mobile/features/recipe/domain/services/smart_recommendation_engine.dart';

void main() {
  group('Hero control and ranking', () {
    test('manual and pinned selections override automatic hero choice', () {
      final now = DateTime(2026, 7, 24, 12);
      final pantry = <pantry_model.Ingredient>[
        _pantryIngredient(
          id: 'shrimp-pantry',
          name: 'กุ้งขาว',
          emoji: '🦐',
          createdAt: now,
        ),
        _pantryIngredient(
          id: 'egg-pantry',
          name: 'ไข่ไก่',
          emoji: '🥚',
          createdAt: now.subtract(const Duration(days: 2)),
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
            heroAliases: const <String>['กุ้งขาว', 'กุ้งสด'],
            extraIngredients: const <String>['garlic'],
          ),
        ),
        ...List<Recipe>.generate(
          2,
          (index) => _recipe(
            id: 'egg_$index',
            name: 'เมนูไข่ $index',
            heroId: 'egg',
            heroName: 'ไข่ไก่',
            heroAliases: const <String>['ไข่'],
            extraIngredients: const <String>['garlic'],
          ),
        ),
      ];
      final matches = const RecipeMatcher().match(
        recipes: recipes,
        pantry: pantry,
      );
      const engine = SmartRecommendationEngine();
      final automatic = engine.build(matches: matches, pantry: pantry);
      final eggOption = automatic.heroOptions.firstWhere(
        (option) => option.key == 'egg',
      );

      final manual = engine.build(
        matches: matches,
        pantry: pantry,
        selectedHeroKey: eggOption.key,
        selectionMode: HeroSelectionMode.manual,
      );
      final pinned = engine.build(
        matches: matches,
        pantry: pantry,
        selectedHeroKey: eggOption.key,
        selectionMode: HeroSelectionMode.pinned,
      );

      expect(automatic.hero?.key, 'shrimp');
      expect(manual.hero?.key, 'egg');
      expect(manual.heroSelectionMode, HeroSelectionMode.manual);
      expect(manual.heroReason, contains('คุณเลือก'));
      expect(pinned.heroSelectionMode, HeroSelectionMode.pinned);
      expect(pinned.heroReason, contains('ปักหมุด'));
    });

    test('each displayed page is sorted by score percentage descending', () {
      final now = DateTime(2026, 7, 24, 12);
      final pantry = <pantry_model.Ingredient>[
        _pantryIngredient(
          id: 'shrimp-pantry',
          name: 'กุ้ง',
          emoji: '🦐',
          createdAt: now,
        ),
        _pantryIngredient(
          id: 'garlic-pantry',
          name: 'กระเทียม',
          emoji: '🧄',
          createdAt: now,
        ),
      ];
      final recipes = <Recipe>[
        _recipe(
          id: 'score_100',
          name: 'ครบทั้งหมด',
          heroId: 'shrimp',
          heroName: 'กุ้ง',
          extraIngredients: const <String>['garlic'],
        ),
        _recipe(
          id: 'score_67',
          name: 'ครบสองในสาม',
          heroId: 'shrimp',
          heroName: 'กุ้ง',
          extraIngredients: const <String>['garlic', 'soy_sauce'],
        ),
        _recipe(
          id: 'score_50',
          name: 'ครบสองในสี่',
          heroId: 'shrimp',
          heroName: 'กุ้ง',
          extraIngredients: const <String>[
            'garlic',
            'soy_sauce',
            'onion',
          ],
        ),
        _recipe(
          id: 'score_40',
          name: 'ครบสองในห้า',
          heroId: 'shrimp',
          heroName: 'กุ้ง',
          extraIngredients: const <String>[
            'garlic',
            'soy_sauce',
            'onion',
            'pepper',
          ],
        ),
        _recipe(
          id: 'score_33',
          name: 'ครบสองในหก',
          heroId: 'shrimp',
          heroName: 'กุ้ง',
          extraIngredients: const <String>[
            'garlic',
            'soy_sauce',
            'onion',
            'pepper',
            'salt',
          ],
        ),
      ];
      final matches = const RecipeMatcher().match(
        recipes: recipes,
        pantry: pantry,
      );
      final result = const SmartRecommendationEngine().build(
        matches: matches,
        pantry: pantry,
      );
      final scores = result.primaryMatches
          .map((match) => match.scorePercent)
          .toList(growable: false);
      final sortedScores = <int>[...scores]..sort((a, b) => b.compareTo(a));

      expect(scores, sortedScores);
      expect(scores.first, 100);
      expect(scores.last, lessThan(scores.first));
    });

    test('an unavailable pinned key falls back to automatic selection', () {
      final now = DateTime(2026, 7, 24, 12);
      final pantry = <pantry_model.Ingredient>[
        _pantryIngredient(
          id: 'egg-pantry',
          name: 'ไข่ไก่',
          emoji: '🥚',
          createdAt: now,
        ),
      ];
      final recipes = <Recipe>[
        _recipe(
          id: 'egg_1',
          name: 'ไข่เจียว',
          heroId: 'egg',
          heroName: 'ไข่ไก่',
          heroAliases: const <String>['ไข่'],
          extraIngredients: const <String>['garlic'],
        ),
      ];
      final matches = const RecipeMatcher().match(
        recipes: recipes,
        pantry: pantry,
      );
      final result = const SmartRecommendationEngine().build(
        matches: matches,
        pantry: pantry,
        selectedHeroKey: 'shrimp',
        selectionMode: HeroSelectionMode.pinned,
      );

      expect(result.hero?.key, 'egg');
      expect(result.heroSelectionMode, HeroSelectionMode.automatic);
      expect(result.requestedSelectionAvailable, isFalse);
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
  List<String> heroAliases = const <String>[],
  List<String> extraIngredients = const <String>[],
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
        aliases: heroAliases,
      ),
      ...extraIngredients.map(_ingredient),
    ],
    steps: const <String>['ทำให้สุก'],
  );
}

RecipeIngredient _ingredient(String id) {
  const names = <String, String>{
    'garlic': 'กระเทียม',
    'soy_sauce': 'ซีอิ๊วขาว',
    'onion': 'หอมหัวใหญ่',
    'pepper': 'พริกไทย',
    'salt': 'เกลือ',
  };

  return RecipeIngredient(
    id: id,
    name: names[id] ?? id,
    quantity: 1,
    unit: 'ส่วน',
  );
}