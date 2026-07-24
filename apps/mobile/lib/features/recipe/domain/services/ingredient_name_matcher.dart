import '../entities/recipe_ingredient.dart';

String normalizeRecipeIngredientName(String value) {
  var normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '');

  for (final suffix in const <String>['สด', 'ซอย', 'สับ']) {
    if (normalized.length > suffix.length && normalized.endsWith(suffix)) {
      normalized = normalized.substring(0, normalized.length - suffix.length);
    }
  }

  const meatPrefix = 'เนื้อ';
  if (normalized.length > meatPrefix.length &&
      normalized.startsWith(meatPrefix)) {
    normalized = normalized.substring(meatPrefix.length);
  }

  return normalized;
}

bool recipeIngredientMatchesPantryName(
  RecipeIngredient ingredient,
  String pantryName,
) {
  final pantryKey = normalizeRecipeIngredientName(pantryName);
  if (pantryKey.isEmpty) {
    return false;
  }

  final candidateKeys = <String>{
    normalizeRecipeIngredientName(ingredient.name),
    ...ingredient.aliases.map(normalizeRecipeIngredientName),
  }..removeWhere((candidate) => candidate.isEmpty);

  return candidateKeys.contains(pantryKey);
}
