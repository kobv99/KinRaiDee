import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pantry/data/ingredient_hierarchy_loader.dart';
import 'package:mobile/features/pantry/domain/models/ingredient_hierarchy.dart';
import 'package:mobile/features/recipe/data/datasources/local_recipe_datasource.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all cross-system references use canonical selectable leaves', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final hierarchy = await IngredientHierarchyLoader().load(
      registry: registry,
    );
    final recipes = await const LocalRecipeDataSource().loadRecipes();
    final navigationIds = <String>{};
    final leafCanonicalIds = <String>{};

    void visit(IngredientHierarchyNode node) {
      if (node.selectable) {
        leafCanonicalIds.add(node.canonicalIngredientId!);
      } else {
        navigationIds.add(node.id);
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(hierarchy.root);
    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        expect(
          registry.byId(ingredient.canonicalIngredientId),
          isNotNull,
          reason:
              '${recipe.id} references unknown ${ingredient.canonicalIngredientId}',
        );
        expect(
          navigationIds,
          isNot(contains(ingredient.canonicalIngredientId)),
          reason: '${recipe.id} references a navigation node',
        );
        expect(
          leafCanonicalIds,
          contains(ingredient.canonicalIngredientId),
          reason:
              '${recipe.id}/${ingredient.canonicalIngredientId} is not selectable',
        );
      }
      for (final step in recipe.instructions) {
        expect(step.title.trim(), isNotEmpty, reason: recipe.id);
        expect(step.instruction.trim(), isNotEmpty, reason: recipe.id);
        for (final ingredientId in step.ingredientIds) {
          expect(
            recipe.ingredients.any(
              (ingredient) => ingredient.canonicalIngredientId == ingredientId,
            ),
            isTrue,
            reason: '${recipe.id} step references undeclared $ingredientId',
          );
        }
      }
    }
  });

  test('Thai Pantry Essentials are localized and selectable', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final hierarchy = await IngredientHierarchyLoader().load(
      registry: registry,
    );
    const essentialIds = <String>{
      'fish_sauce',
      'soy_sauce',
      'dark_soy_sauce',
      'oyster_sauce',
      'cooking_oil',
      'garlic',
      'shallot',
      'onion',
      'chili',
      'lime',
      'holy_basil',
      'sweet_basil',
      'coriander',
      'spring_onion',
      'lemongrass',
      'galangal',
      'kaffir_lime_leaf',
      'palm_sugar',
      'sugar',
      'salt',
      'pepper',
    };
    final selectableIds = hierarchy
        .search('')
        .map((result) => result.ingredient.canonicalIngredientId)
        .toSet();
    // Empty-query search intentionally returns no UI results, so traverse.
    void collect(IngredientHierarchyNode node) {
      if (node.selectable) selectableIds.add(node.canonicalIngredientId);
      for (final child in node.children) {
        collect(child);
      }
    }

    collect(hierarchy.root);
    for (final id in essentialIds) {
      final ingredient = registry.byId(id);
      expect(ingredient, isNotNull, reason: '$id is missing');
      expect(ingredient!.displayName().trim(), isNotEmpty, reason: id);
      expect(selectableIds, contains(id), reason: '$id is not selectable');
    }
  });
}
