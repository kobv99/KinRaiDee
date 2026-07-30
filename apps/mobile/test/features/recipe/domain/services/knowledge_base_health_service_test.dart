import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/knowledge_base_health_service.dart';

void main() {
  test('reports coverage, duplicate aliases, and broken references', () {
    final registry = CanonicalIngredientRegistry(
      ingredients: <CanonicalIngredient>[
        _ingredient('used', aliases: const <String>['shared']),
        _ingredient('unused', aliases: const <String>['shared']),
      ],
    );
    final report = const KnowledgeBaseHealthService().inspect(
      registry: registry,
      recipes: const <Recipe>[
        Recipe(
          id: 'valid',
          name: 'Valid',
          category: 'test',
          heroIngredientId: 'used',
          ingredients: <RecipeIngredient>[
            RecipeIngredient(
              id: 'used',
              name: 'Used',
              quantity: 1,
              unit: 'piece',
            ),
          ],
          steps: <String>[],
        ),
        Recipe(
          id: 'broken',
          name: 'Broken',
          category: 'test',
          heroIngredientId: 'missing',
          ingredients: <RecipeIngredient>[
            RecipeIngredient(
              id: 'missing',
              name: 'Missing',
              quantity: 1,
              unit: 'piece',
            ),
          ],
          steps: <String>[],
        ),
      ],
      substitutions: const [],
    );

    expect(report.canonicalIngredientCount, 2);
    expect(report.recipeCount, 2);
    expect(report.ingredientsWithoutRecipes, contains('unused'));
    expect(report.duplicateAliases.single, contains('shared'));
    expect(report.brokenIngredientReferences, contains('broken:missing'));
    expect(report.brokenRecipeMappings, contains('broken:missing'));
  });
}

CanonicalIngredient _ingredient(
  String id, {
  List<String> aliases = const <String>[],
}) {
  return CanonicalIngredient(
    id: id,
    canonicalName: id,
    localizedNames: <String, String>{'th': id},
    aliases: aliases,
    searchKeywords: const <String>[],
    category: 'test',
    defaultStorageType: IngredientStorageType.pantry,
    defaultPurchaseUnitId: 'piece',
    defaultInventoryUnitId: 'piece',
  );
}
