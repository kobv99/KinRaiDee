import '../../../../core/domain/images/image_metadata.dart';
import 'recipe_ingredient.dart';
import 'recipe_compatibility.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.ingredients,
    required this.steps,
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
    this.imageUrl,
    this.image,
    this.compatibility = const RecipeCompatibilityMetadata(),
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
  final String? sourceUrl;
  final bool discoveredByAi;
  final RecipeCompatibilityMetadata compatibility;

  /// Optional remote image for this recipe. Absent or failing to load must
  /// always fall back to [emoji] — never fabricate imagery or rating data.
  final String? imageUrl;

  /// Structured image foundation metadata. This is the source of truth for
  /// all new image data — unlike [imageUrl], its [ImageMetadata.reviewStatus]
  /// and [ImageMetadata.provenance] come entirely from the content itself
  /// rather than being assumed by an adapter.
  final ImageMetadata? image;

  /// Resolves this recipe's image, preferring the structured [image] field
  /// over the legacy [imageUrl] adapter, without changing [imageUrl]'s
  /// stored shape or JSON parsing.
  ///
  /// Precedence:
  /// 1. [image], when present — used verbatim, including whatever
  ///    [ImageMetadata.reviewStatus]/[ImageMetadata.provenance] it declares.
  /// 2. Otherwise, a populated [imageUrl] is treated as pre-approved: it was
  ///    already being rendered directly (unconditionally) by earlier code, so
  ///    marking it [ImageReviewStatus.approved] here is what actually
  ///    preserves that existing behavior under the foundation's new
  ///    approved-only rendering policy.
  /// 3. Otherwise, [ImageLocationType.none].
  ImageMetadata get imageMetadata {
    final structured = image;
    if (structured != null) {
      return structured;
    }
    final url = imageUrl;
    if (url == null) {
      return ImageMetadata(locationType: ImageLocationType.none);
    }
    return ImageMetadata(
      locationType: ImageLocationType.network,
      remoteUrl: url,
      reviewStatus: ImageReviewStatus.approved,
    );
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
    final nestedCompatibility = json['compatibility'];
    final compatibilityJson = nestedCompatibility is Map
        ? <String, dynamic>{
            ...json,
            ...Map<String, dynamic>.from(nestedCompatibility),
          }
        : json;
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
      steps: _stringList(json['steps']),
      sourceUrl: json['sourceUrl'] as String?,
      discoveredByAi: json['discoveredByAi'] as bool? ?? false,
      imageUrl: _nonEmptyString(json['imageUrl']),
      image: json['image'] is Map
          ? ImageMetadata.fromJson(
              Map<String, dynamic>.from(json['image'] as Map),
            )
          : null,
      compatibility: RecipeCompatibilityMetadata.fromJson(compatibilityJson),
    );
  }
}

String? _nonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _stringList(Object? value) {
  if (value is String) {
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}
