import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../substitution/domain/entities/ingredient_substitution.dart';
import '../entities/knowledge_base_health.dart';
import '../entities/recipe.dart';

class KnowledgeBaseHealthService {
  const KnowledgeBaseHealthService();

  KnowledgeBaseHealth inspect({
    required CanonicalIngredientRegistry registry,
    required List<Recipe> recipes,
    required List<IngredientSubstitution> substitutions,
  }) {
    final ingredients = registry.ingredients;
    final referencedIds = <String>{};
    final brokenReferences = <String>[];
    final brokenMappings = <String>[];
    final recipesWithoutIngredients = <String>[];

    for (final recipe in recipes) {
      if (recipe.ingredients.isEmpty) {
        recipesWithoutIngredients.add(recipe.id);
      }
      for (final ingredient in recipe.ingredients) {
        final id = ingredient.canonicalIngredientId;
        final canonicalId = registry.canonicalIdFor(id);
        if (canonicalId == null) {
          brokenReferences.add('${recipe.id}:$id');
        } else {
          referencedIds.add(canonicalId);
        }
      }
      final heroId = recipe.heroIngredientId;
      if (heroId != null && registry.canonicalIdFor(heroId) == null) {
        brokenMappings.add('${recipe.id}:$heroId');
      }
    }

    final substitutionSourceIds = <String>{};
    for (final item in substitutions) {
      final original = registry.canonicalIdFor(item.originalIngredientId);
      final substitute = registry.canonicalIdFor(item.substituteIngredientId);
      if (original == null || substitute == null) {
        brokenReferences.add(
          'substitution:${item.originalIngredientId}->'
          '${item.substituteIngredientId}',
        );
      } else {
        substitutionSourceIds.add(original);
      }
    }

    final aliases = <String, Set<String>>{};
    for (final ingredient in ingredients) {
      for (final alias in ingredient.aliases) {
        final normalized = normalizeIngredientKey(alias);
        if (normalized.isNotEmpty) {
          aliases.putIfAbsent(normalized, () => <String>{}).add(ingredient.id);
        }
      }
    }

    List<String> sorted(Iterable<String> values) =>
        values.toSet().toList(growable: false)..sort();

    return KnowledgeBaseHealth(
      canonicalIngredientCount: ingredients.length,
      recipeCount: recipes.length,
      recipesWithoutIngredients: sorted(recipesWithoutIngredients),
      ingredientsWithoutRecipes: sorted(
        ingredients
            .where((item) => !referencedIds.contains(item.id))
            .map((item) => item.id),
      ),
      ingredientsWithoutSubstitutions: sorted(
        ingredients
            .where(
              (item) =>
                  item.substitutable &&
                  referencedIds.contains(item.id) &&
                  !substitutionSourceIds.contains(item.id),
            )
            .map((item) => item.id),
      ),
      duplicateAliases: sorted(
        aliases.entries
            .where((entry) => entry.value.length > 1)
            .map((entry) => '${entry.key}:${entry.value.join(',')}'),
      ),
      brokenIngredientReferences: sorted(brokenReferences),
      brokenRecipeMappings: sorted(brokenMappings),
    );
  }
}
