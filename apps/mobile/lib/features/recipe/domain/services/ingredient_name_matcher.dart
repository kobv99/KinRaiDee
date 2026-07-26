import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/models/ingredient.dart' as pantry_model;
import '../entities/recipe_ingredient.dart';

const Map<String, String> _ingredientFamilyAliases = <String, String>{
  'สันคอหมู': 'หมู',
  'คอหมู': 'หมู',
  'หมูสามชั้น': 'หมู',
  'สามชั้น': 'หมู',
  'หมูบด': 'หมู',
  'หมูชิ้น': 'หมู',
  'หมูสไลซ์': 'หมู',
  'หมูเด้ง': 'หมู',
  'วัวสไลซ์': 'วัว',
  'เนื้อวัวสไลซ์': 'วัว',
  'เนื้อบด': 'วัว',
  'เนื้อวัวบด': 'วัว',
  'เนื้อชิ้น': 'วัว',
  'เนื้อวัวชิ้น': 'วัว',
};

String normalizeRecipeIngredientName(String value) {
  var normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

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

  return _ingredientFamilyAliases[normalized] ?? normalized;
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

bool recipeIngredientMatchesPantry(
  RecipeIngredient ingredient,
  pantry_model.Ingredient pantryIngredient, {
  CanonicalIngredientRegistry? registry,
}) {
  final pantryCanonicalId = pantryIngredient.canonicalIngredientId;
  if (pantryCanonicalId.isNotEmpty) {
    if (pantryCanonicalId == ingredient.id) {
      return true;
    }
    return registry?.areCompatibleIds(pantryCanonicalId, ingredient.id) ??
        false;
  }

  // Read-only compatibility path for pre-migration test fixtures and imports.
  return recipeIngredientMatchesPantryName(ingredient, pantryIngredient.name);
}
