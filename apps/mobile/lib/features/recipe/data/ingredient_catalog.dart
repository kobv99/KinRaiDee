import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/entities/ingredient.dart';

class IngredientCatalog {
  IngredientCatalog({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<Ingredient>> load({
    String assetPath = 'assets/ingredients/thai_ingredients.json',
  }) async {
    final source = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(source) as List<dynamic>;

    return decoded
        .map(
          (item) => Ingredient.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Ingredient? findByName(Iterable<Ingredient> ingredients, String value) {
    for (final ingredient in ingredients) {
      if (ingredient.matches(value)) {
        return ingredient;
      }
    }
    return null;
  }
}
