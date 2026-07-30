import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/data/recipe_ingredient_catalog.dart';
import 'package:mobile/features/recipe/data/recipe_pack_parser.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_step.dart';

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
    expect(recipe.instructions.length, greaterThanOrEqualTo(5));
    expect(
      recipe.instructions,
      everyElement(
        isA<RecipeStep>()
            .having((step) => step.title, 'title', isNotEmpty)
            .having((step) => step.instruction, 'instruction', isNotEmpty)
            .having((step) => step.completionCue, 'completion cue', isNotEmpty),
      ),
    );
  });

  test('authored structured steps keep variable length and metadata', () {
    final catalog = RecipeIngredientCatalog.fromJson(<String, dynamic>{
      'ingredients': const <Map<String, dynamic>>[],
    });
    final parser = RecipePackParser(catalog: catalog);
    final authored = List<Map<String, dynamic>>.generate(
      7,
      (index) => <String, dynamic>{
        'title': 'Step ${index + 1}',
        'instruction': 'Perform the specific cooking action ${index + 1}.',
        'durationMinutes': index + 1,
        'heatLevel': 'medium',
        'completionCue': 'cue ${index + 1}',
      },
    );

    final recipe = parser.parse(<String, dynamic>{
      'version': 2,
      'hero': <String, dynamic>{
        'id': 'rice',
        'name': 'Rice',
        'quantity': 1,
        'unit': 'cup',
      },
      'recipes': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'structured',
          'name': 'Structured',
          'method': 'ต้ม',
          'ingredients': const <Object>[],
          'steps': authored,
        },
      ],
    }).single;

    expect(recipe.instructions, hasLength(7));
    expect(recipe.steps, hasLength(7));
    expect(recipe.instructions.last.durationMinutes, 7);
    expect(recipe.instructions.last.completionCue, 'cue 7');
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
}
