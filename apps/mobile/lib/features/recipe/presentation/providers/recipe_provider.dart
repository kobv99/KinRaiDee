import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/pantry_provider.dart';
import '../../data/datasources/local_recipe_datasource.dart';
import '../../data/repositories/local_recipe_repository.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_match.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_matcher.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return const LocalRecipeRepository(LocalRecipeDataSource());
});

final recipesProvider = FutureProvider<List<Recipe>>((ref) {
  return ref.read(recipeRepositoryProvider).getRecipes();
});

final recipeMatchesProvider = FutureProvider<List<RecipeMatch>>((ref) async {
  final recipes = await ref.watch(recipesProvider.future);
  final pantry = ref.watch(pantryProvider);

  return const RecipeMatcher().match(recipes: recipes, pantry: pantry);
});
