import '../entities/ingredient_substitution.dart';

class IngredientCompatibilityCalculator {
  const IngredientCompatibilityCalculator();

  double calculate(IngredientSubstitution value) =>
      ((value.confidence * 0.4) +
              (value.flavorSimilarity * 0.25) +
              (value.textureSimilarity * 0.15) +
              (value.cookingMethodCompatibility * 0.2))
          .clamp(0, 1)
          .toDouble();
}
