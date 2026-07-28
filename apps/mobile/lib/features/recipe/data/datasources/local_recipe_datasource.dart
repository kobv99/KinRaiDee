import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/recipe.dart';
import '../recipe_ingredient_catalog.dart';
import '../recipe_pack_parser.dart';

class LocalRecipeDataSource {
  const LocalRecipeDataSource({this.bundle});

  static const String ingredientCatalogAssetPath =
      'assets/recipes/ingredient_catalog.json';

  static const List<String> defaultAssetPaths = <String>[
    'assets/recipes/thai.json',
    'assets/recipes/shrimp.json',
    'assets/recipes/squid.json',
    'assets/recipes/pork.json',
    'assets/recipes/chicken.json',
    'assets/recipes/beef.json',
    'assets/recipes/fish.json',
    'assets/recipes/egg.json',
    'assets/recipes/salted_egg.json',
  ];

  final AssetBundle? bundle;

  Future<List<Recipe>> loadRecipes({
    List<String> assetPaths = defaultAssetPaths,
    String catalogAssetPath = ingredientCatalogAssetPath,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    final catalog = RecipeIngredientCatalog.fromJson(
      jsonDecode(await assetBundle.loadString(catalogAssetPath)),
    );
    final parser = RecipePackParser(catalog: catalog);
    final recipes = <Recipe>[];
    final recipeIds = <String>{};

    for (final assetPath in assetPaths) {
      final raw = await assetBundle.loadString(assetPath);
      final parsedRecipes = parser.parse(jsonDecode(raw));

      for (final recipe in parsedRecipes) {
        if (!recipeIds.add(recipe.id)) {
          throw const FormatException('Recipe data contains a duplicate id.');
        }
        recipes.add(recipe);
      }
    }

    return List<Recipe>.unmodifiable(recipes);
  }
}
