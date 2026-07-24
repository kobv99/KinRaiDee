import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/recipe.dart';
import '../recipe_pack_parser.dart';

class LocalRecipeDataSource {
  const LocalRecipeDataSource({this.bundle});

  static const List<String> defaultAssetPaths = <String>[
    'assets/recipes/thai.json',
    'assets/recipes/shrimp.json',
    'assets/recipes/squid.json',
    'assets/recipes/pork.json',
    'assets/recipes/chicken.json',
    'assets/recipes/egg.json',
  ];

  final AssetBundle? bundle;

  Future<List<Recipe>> loadRecipes({
    List<String> assetPaths = defaultAssetPaths,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    final parser = const RecipePackParser();
    final recipes = <Recipe>[];
    final recipeIds = <String>{};

    for (final assetPath in assetPaths) {
      final raw = await assetBundle.loadString(assetPath);
      final parsedRecipes = parser.parse(jsonDecode(raw));

      for (final recipe in parsedRecipes) {
        if (!recipeIds.add(recipe.id)) {
          throw FormatException('Duplicate recipe id: ${recipe.id}');
        }
        recipes.add(recipe);
      }
    }

    return List<Recipe>.unmodifiable(recipes);
  }
}
