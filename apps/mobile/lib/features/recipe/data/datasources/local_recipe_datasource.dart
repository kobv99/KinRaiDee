import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/recipe.dart';

class LocalRecipeDataSource {
  const LocalRecipeDataSource();

  Future<List<Recipe>> loadRecipes() async {
    final raw = await rootBundle.loadString('assets/recipes/thai.json');
    final decoded = jsonDecode(raw) as List<dynamic>;

    return decoded
        .map(
          (item) => Recipe.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }
}
