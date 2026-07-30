import 'recipe_ingredient.dart';
import 'recipe_step.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.ingredients,
    required this.steps,
    this.detailedSteps = const <RecipeStep>[],
    this.version = 1,
    this.description = '',
    this.emoji = '🍳',
    this.difficulty = 'easy',
    this.cookTimeMinutes = 0,
    this.servings = 1,
    this.tags = const <String>[],
    this.cookingMethods = const <String>[],
    this.heroIngredientId,
    this.heroIngredientName,
    this.popularity = 0,
    this.sourceUrl,
    this.discoveredByAi = false,
    this.supportsSubstitutions = true,
  });

  final int version;
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
  final String? heroIngredientId;
  final String? heroIngredientName;
  final int popularity;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<RecipeStep> detailedSteps;
  final String? sourceUrl;
  final bool discoveredByAi;
  final bool supportsSubstitutions;

  List<RecipeStep> get instructions {
    if (detailedSteps.isNotEmpty) {
      return detailedSteps;
    }
    return steps.indexed
        .map(
          (entry) => RecipeStep(
            title: 'ขั้นตอน ${entry.$1 + 1}',
            instruction: entry.$2,
          ),
        )
        .toList(growable: false);
  }

  RecipeIngredient? get heroIngredient {
    final explicitId = heroIngredientId?.trim();
    if (explicitId != null && explicitId.isNotEmpty) {
      for (final ingredient in ingredients) {
        if (ingredient.id == explicitId) {
          return ingredient;
        }
      }
    }

    final explicitName = heroIngredientName?.trim();
    if (explicitName != null && explicitName.isNotEmpty) {
      for (final ingredient in ingredients) {
        if (ingredient.name == explicitName) {
          return ingredient;
        }
      }
    }

    for (final ingredient in ingredients) {
      if (ingredient.required) {
        return ingredient;
      }
    }

    return ingredients.isEmpty ? null : ingredients.first;
  }

  String get resolvedHeroIngredientId => heroIngredient?.id ?? '';

  String get resolvedHeroIngredientName =>
      heroIngredientName?.trim().isNotEmpty == true
      ? heroIngredientName!.trim()
      : heroIngredient?.name ?? '';

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      version: (json['version'] as num?)?.toInt() ?? 1,
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'ทั่วไป',
      description: json['description'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🍳',
      difficulty: json['difficulty'] as String? ?? 'easy',
      cookTimeMinutes:
          (json['cookTimeMinutes'] as num?)?.toInt() ??
          (json['cookTime'] as num?)?.toInt() ??
          0,
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      tags: _stringList(json['tags']),
      cookingMethods: _stringList(
        json['cookingMethods'] ?? json['cookingMethod'],
      ),
      heroIngredientId: json['heroIngredientId'] as String?,
      heroIngredientName: json['heroIngredientName'] as String?,
      popularity: (json['popularity'] as num?)?.toInt() ?? 0,
      ingredients: (json['ingredients'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (ingredient) => RecipeIngredient.fromJson(
              Map<String, dynamic>.from(ingredient as Map),
            ),
          )
          .toList(growable: false),
      steps: _legacyStepStrings(json['steps']),
      detailedSteps: _detailedRecipeSteps(json['steps']),
      sourceUrl: json['sourceUrl'] as String?,
      discoveredByAi: json['discoveredByAi'] as bool? ?? false,
      supportsSubstitutions: json['supportsSubstitutions'] as bool? ?? true,
    );
  }
}

List<RecipeStep> _recipeSteps(Object? value) {
  final rows = value as List<dynamic>? ?? const <dynamic>[];
  return rows.indexed
      .map((entry) => RecipeStep.fromJson(entry.$2, index: entry.$1))
      .toList(growable: false);
}

List<RecipeStep> _detailedRecipeSteps(Object? value) {
  final rows = value as List<dynamic>? ?? const <dynamic>[];
  if (rows.isEmpty || rows.any((row) => row is! Map)) {
    return const <RecipeStep>[];
  }
  return _recipeSteps(rows);
}

List<String> _legacyStepStrings(Object? value) {
  return _recipeSteps(
    value,
  ).map((step) => step.instruction).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is String) {
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}
