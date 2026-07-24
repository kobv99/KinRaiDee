import 'recipe_ingredient.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.ingredients,
    required this.steps,
    this.description = '',
    this.emoji = '🍳',
    this.difficulty = 'easy',
    this.cookTimeMinutes = 0,
    this.servings = 1,
    this.tags = const <String>[],
    this.cookingMethods = const <String>[],
    this.sourceUrl,
    this.discoveredByAi = false,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String emoji;
  final String difficulty;
  final int cookTimeMinutes;
  final int servings;
  final List<String> tags;
  final List<String> cookingMethods;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String? sourceUrl;
  final bool discoveredByAi;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'ทั่วไป',
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🍳',
      difficulty: json['difficulty'] as String? ?? 'easy',
      cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.toInt() ??
          (json['cookTime'] as num?)?.toInt() ??
          0,
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      tags: _stringList(json['tags']),
      cookingMethods: _stringList(
        json['cookingMethods'] ?? json['cookingMethod'],
      ),
      ingredients: (json['ingredients'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (ingredient) => RecipeIngredient.fromJson(
              Map<String, dynamic>.from(ingredient as Map),
            ),
          )
          .toList(growable: false),
      steps: _stringList(json['steps']),
      sourceUrl: json['sourceUrl'] as String?,
      discoveredByAi: json['discoveredByAi'] as bool? ?? false,
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is String) {
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}
