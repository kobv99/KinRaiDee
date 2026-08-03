import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/recipe_ingredient_catalog.dart';
import 'package:mobile/features/recipe/data/recipe_pack_parser.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';

void main() {
  test('Recipe role and weight metadata comes from data', () {
    final catalog = RecipeIngredientCatalog.fromJson(<String, dynamic>{
      'ingredients': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'holy_basil',
          'name': 'Holy Basil',
          'quantity': 1,
          'unit': 'piece',
          'role': 'secondary',
          'weight': 10,
        },
        <String, dynamic>{
          'id': 'garlic',
          'name': 'Garlic',
          'quantity': 1,
          'unit': 'piece',
          'role': 'secondary',
          'weight': 5,
        },
      ],
    });
    final parser = RecipePackParser(catalog: catalog);

    final recipe = parser.parse(<String, dynamic>{
      'version': 2,
      'hero': <String, dynamic>{
        'id': 'pork',
        'name': 'Pork',
        'quantity': 1,
        'unit': 'piece',
        'role': 'primary',
        'weight': 40,
      },
      'recipes': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'pad-kra-pao',
          'name': 'Pad Kra Pao',
          'method': 'ผัด',
          'ingredients': <Object>[
            <String, dynamic>{
              'id': 'holy_basil',
              'role': 'primary',
              'weight': 35,
            },
            <String, dynamic>{
              'id': 'garlic',
              'role': 'secondary',
              'weight': 10,
            },
          ],
        },
      ],
    }).single;

    expect(recipe.ingredients[0].role, RecipeIngredientRole.primary);
    expect(recipe.ingredients[0].weight, 40);
    expect(recipe.ingredients[1].role, RecipeIngredientRole.primary);
    expect(recipe.ingredients[1].weight, 35);
    expect(recipe.ingredients[2].role, RecipeIngredientRole.secondary);
    expect(recipe.ingredients[2].weight, 10);
  });

  test('legacy string ingredient reads defaults from the catalog', () {
    final catalog = RecipeIngredientCatalog.fromJson(<String, dynamic>{
      'ingredients': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'garlic',
          'name': 'Garlic',
          'quantity': 4,
          'unit': 'piece',
          'role': 'secondary',
          'weight': 10,
        },
      ],
    });
    final ingredient = catalog.build('garlic');

    expect(ingredient.name, 'Garlic');
    expect(ingredient.quantity, 4);
    expect(ingredient.role, RecipeIngredientRole.secondary);
    expect(ingredient.weight, 10);
  });

  test(
    'recipe row compatibility overrides pack defaults deterministically',
    () {
      final parser = RecipePackParser(
        catalog: RecipeIngredientCatalog.fromJson(<String, dynamic>{
          'ingredients': <Map<String, dynamic>>[],
        }),
      );

      final recipes = parser.parse(<String, dynamic>{
        'version': 2,
        'hero': <String, dynamic>{
          'id': 'fish',
          'name': 'ปลา',
          'quantity': 1,
          'unit': 'ตัว',
        },
        'exactIngredientIds': <String>['fish'],
        'excludedIngredientIds': <String>['mackerel'],
        'requiredIngredientForm': 'boneless_fillet',
        'requiredTexture': 'firm_white_flesh',
        'recipes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'generic-fillet',
            'name': 'ปลาเนื้อขาวผัด',
            'method': 'ผัด',
            'ingredients': <Object>[],
          },
          <String, dynamic>{
            'id': 'whole-mackerel',
            'name': 'ปลาทอดทั้งตัว',
            'method': 'ทอด',
            'ingredients': <Object>[],
            'compatibleIngredientIds': <String>['mackerel'],
            'excludedIngredientIds': <String>[],
            'requiredIngredientForm': 'whole_cleaned',
            'requiredTexture': 'oily_tender',
          },
        ],
      });

      expect(recipes.first.compatibility.excludedIngredientIds, ['mackerel']);
      expect(recipes.first.compatibility.requiredIngredientForms, [
        'boneless_fillet',
      ]);
      expect(recipes.last.compatibility.compatibleIngredientIds, ['mackerel']);
      expect(recipes.last.compatibility.excludedIngredientIds, isEmpty);
      expect(recipes.last.compatibility.requiredIngredientForms, [
        'whole_cleaned',
      ]);
      expect(recipes.last.compatibility.requiredTexture, 'oily_tender');
    },
  );

  group('step count varies with recipe complexity', () {
    RecipePackParser buildParser() {
      final catalog = RecipeIngredientCatalog.fromJson(<String, dynamic>{
        'ingredients': <Map<String, dynamic>>[],
      });
      return RecipePackParser(catalog: catalog);
    }

    Map<String, dynamic> pack({required String difficulty, required int time}) {
      return <String, dynamic>{
        'version': 1,
        'hero': <String, dynamic>{
          'id': 'pork',
          'name': 'หมู',
          'quantity': 1,
          'unit': 'ชิ้น',
        },
        'recipes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r1',
            'name': 'Test',
            'method': 'ผัด',
            'difficulty': difficulty,
            'time': time,
            'ingredients': <Object>[],
          },
        ],
      };
    }

    test('an easy, quick recipe gets a compact 4-5 step list', () {
      final recipe = buildParser()
          .parse(pack(difficulty: 'easy', time: 15))
          .single;
      expect(recipe.steps.length, inInclusiveRange(4, 5));
    });

    test('a medium, moderate-time recipe gets a fuller 6-8 step list', () {
      final recipe = buildParser()
          .parse(pack(difficulty: 'medium', time: 20))
          .single;
      expect(recipe.steps.length, inInclusiveRange(6, 8));
    });

    test('a medium, long-cooking recipe gets extra refinement steps', () {
      final recipe = buildParser()
          .parse(pack(difficulty: 'medium', time: 40))
          .single;
      final quick = buildParser()
          .parse(pack(difficulty: 'easy', time: 15))
          .single;

      expect(recipe.steps.length, greaterThan(quick.steps.length));
      expect(recipe.steps.length, greaterThanOrEqualTo(8));
    });

    test('different recipes in the same pack can have different step counts', () {
      final catalog = RecipeIngredientCatalog.fromJson(<String, dynamic>{
        'ingredients': <Map<String, dynamic>>[],
      });
      final recipes = RecipePackParser(catalog: catalog).parse(
        <String, dynamic>{
          'version': 1,
          'hero': <String, dynamic>{
            'id': 'pork',
            'name': 'หมู',
            'quantity': 1,
            'unit': 'ชิ้น',
          },
          'recipes': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'quick',
              'name': 'Quick',
              'method': 'ผัด',
              'difficulty': 'easy',
              'time': 10,
              'ingredients': <Object>[],
            },
            <String, dynamic>{
              'id': 'involved',
              'name': 'Involved',
              'method': 'แกง',
              'difficulty': 'medium',
              'time': 45,
              'ingredients': <Object>[],
            },
          ],
        },
      );

      final stepCounts = recipes.map((r) => r.steps.length).toSet();
      expect(
        stepCounts.length,
        greaterThan(1),
        reason:
            'recipes of different complexity must not all have the same step count',
      );
    });

    test('no generated step list is a vague single combined instruction', () {
      for (final difficulty in ['easy', 'medium']) {
        for (final time in [10, 40]) {
          final recipe = buildParser()
              .parse(pack(difficulty: difficulty, time: time))
              .single;
          expect(recipe.steps.length, greaterThanOrEqualTo(4));
          expect(recipe.steps, everyElement(isNotEmpty));
        }
      }
    });
  });
}
