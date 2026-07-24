import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/recipe.dart';

class LocalRecipeDataSource {
  const LocalRecipeDataSource({AssetBundle? bundle}) : _bundle = bundle;

  static const List<String> defaultAssetPaths = <String>[
    'assets/recipes/thai.json',
    'assets/recipes/shrimp.json',
    'assets/recipes/squid.json',
    'assets/recipes/pork.json',
    'assets/recipes/chicken.json',
    'assets/recipes/egg.json',
  ];

  final AssetBundle? _bundle;

  Future<List<Recipe>> loadRecipes({
    List<String> assetPaths = defaultAssetPaths,
  }) async {
    final bundle = _bundle ?? rootBundle;
    final recipes = <Recipe>[];
    final recipeIds = <String>{};

    for (final assetPath in assetPaths) {
      final raw = await bundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as List<dynamic>;

      for (final item in decoded) {
        final recipe = Recipe.fromJson(Map<String, dynamic>.from(item as Map));
        if (!recipeIds.add(recipe.id)) {
          throw FormatException('Duplicate recipe id: ${recipe.id}');
        }
        recipes.add(recipe);
      }
    }

    return List<Recipe>.unmodifiable(recipes);
  }
}
