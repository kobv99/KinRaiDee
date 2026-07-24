import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/pantry_provider.dart';
import '../../data/datasources/local_recipe_datasource.dart';
import '../../data/repositories/local_recipe_repository.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_match.dart';
import '../../domain/entities/smart_recommendation.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_matcher.dart';
import '../../domain/services/smart_recommendation_engine.dart';

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

class RecommendationSessionState {
  const RecommendationSessionState({
    this.pageIndex = 0,
    this.shuffleSeed = 0,
  });

  final int pageIndex;
  final int shuffleSeed;
}

class RecommendationSessionNotifier
    extends Notifier<RecommendationSessionState> {
  static const _pageSize = 5;

  @override
  RecommendationSessionState build() {
    return const RecommendationSessionState();
  }

  void showNext(int candidateCount) {
    final pageCount = candidateCount == 0
        ? 0
        : (candidateCount / _pageSize).ceil();
    if (pageCount <= 1) {
      return;
    }

    final nextPage = state.pageIndex + 1;
    if (nextPage >= pageCount) {
      state = RecommendationSessionState(
        pageIndex: 0,
        shuffleSeed: state.shuffleSeed + 1,
      );
      return;
    }

    state = RecommendationSessionState(
      pageIndex: nextPage,
      shuffleSeed: state.shuffleSeed,
    );
  }

  void reset() {
    state = const RecommendationSessionState();
  }
}

final recommendationSessionProvider =
    NotifierProvider<RecommendationSessionNotifier, RecommendationSessionState>(
      RecommendationSessionNotifier.new,
    );

class SelectedHeroIngredientNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? key) {
    state = key;
  }
}

final selectedHeroIngredientProvider =
    NotifierProvider<SelectedHeroIngredientNotifier, String?>(
      SelectedHeroIngredientNotifier.new,
    );

final smartRecommendationProvider = Provider<AsyncValue<SmartRecommendation>>((
  ref,
) {
  final matches = ref.watch(recipeMatchesProvider);
  final pantry = ref.watch(pantryProvider);
  final selectedHeroKey = ref.watch(selectedHeroIngredientProvider);
  final session = ref.watch(recommendationSessionProvider);

  return matches.whenData(
    (items) => const SmartRecommendationEngine().build(
      matches: items,
      pantry: pantry,
      selectedHeroKey: selectedHeroKey,
      pageIndex: session.pageIndex,
      shuffleSeed: session.shuffleSeed,
    ),
  );
});
