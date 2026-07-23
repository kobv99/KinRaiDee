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
    this.sourceUrl,
    this.discoveredByAi = false,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String emoji;
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
      ingredients: (json['ingredients'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (ingredient) => RecipeIngredient.fromJson(
              Map<String, dynamic>.from(ingredient as Map),
            ),
          )
          .toList(growable: false),
      steps: (json['steps'] as List<dynamic>? ?? const <dynamic>[])
          .map((step) => step.toString())
          .toList(growable: false),
      sourceUrl: json['sourceUrl'] as String?,
      discoveredByAi: json['discoveredByAi'] as bool? ?? false,
    );
  }
}
