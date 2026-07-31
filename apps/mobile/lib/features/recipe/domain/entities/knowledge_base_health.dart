class KnowledgeBaseHealth {
  const KnowledgeBaseHealth({
    required this.canonicalIngredientCount,
    required this.recipeCount,
    required this.recipesWithoutIngredients,
    required this.ingredientsWithoutRecipes,
    required this.ingredientsWithoutSubstitutions,
    required this.duplicateAliases,
    required this.brokenIngredientReferences,
    required this.brokenRecipeMappings,
  });

  final int canonicalIngredientCount;
  final int recipeCount;
  final List<String> recipesWithoutIngredients;
  final List<String> ingredientsWithoutRecipes;
  final List<String> ingredientsWithoutSubstitutions;
  final List<String> duplicateAliases;
  final List<String> brokenIngredientReferences;
  final List<String> brokenRecipeMappings;

  int get issueCount =>
      recipesWithoutIngredients.length +
      ingredientsWithoutRecipes.length +
      ingredientsWithoutSubstitutions.length +
      duplicateAliases.length +
      brokenIngredientReferences.length +
      brokenRecipeMappings.length;
}
