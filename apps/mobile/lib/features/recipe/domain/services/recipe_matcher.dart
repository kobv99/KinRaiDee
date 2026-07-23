import '../../../../core/models/ingredient.dart';
import '../entities/recipe.dart';
import '../entities/recipe_ingredient.dart';
import '../entities/recipe_match.dart';

class RecipeMatcher {
  const RecipeMatcher();

  List<RecipeMatch> match({
    required List<Recipe> recipes,
    required List<Ingredient> pantry,
  }) {
    final pantryNames = pantry
        .where((item) => item.quantity > 0 && !item.isExpired)
        .map((item) => _normalize(item.name))
        .toSet();

    final results = recipes.map((recipe) {
      final matched = <RecipeIngredient>[];
      final missing = <RecipeIngredient>[];

      for (final ingredient in recipe.ingredients) {
        final candidates = <String>{
          _normalize(ingredient.name),
          ...ingredient.aliases.map(_normalize),
        };

        final found = pantryNames.any(
          (pantryName) => candidates.any(
            (candidate) =>
                pantryName == candidate ||
                pantryName.contains(candidate) ||
                candidate.contains(pantryName),
          ),
        );

        if (found) {
          matched.add(ingredient);
        } else {
          missing.add(ingredient);
        }
      }

      final requiredIngredients = recipe.ingredients
          .where((item) => item.required)
          .toList(growable: false);
      final matchedRequired = matched.where((item) => item.required).length;
      final score = requiredIngredients.isEmpty
          ? 1.0
          : matchedRequired / requiredIngredients.length;

      return RecipeMatch(
        recipe: recipe,
        matchedIngredients: matched,
        missingIngredients: missing,
        score: score,
      );
    }).toList(growable: false);

    return [...results]
      ..sort((first, second) {
        final scoreComparison = second.score.compareTo(first.score);
        if (scoreComparison != 0) {
          return scoreComparison;
        }

        return first.missingIngredients.length.compareTo(
          second.missingIngredients.length,
        );
      });
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('เนื้อ', '')
        .replaceAll('สด', '')
        .replaceAll('ซอย', '')
        .replaceAll('สับ', '');
  }
}
