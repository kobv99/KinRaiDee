import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../data/datasources/local_recipe_datasource.dart';
import '../../data/repositories/local_hero_selection_repository.dart';
import '../../data/repositories/local_recipe_repository.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_match.dart';
import '../../domain/entities/recipe_readiness.dart';
import '../../domain/entities/smart_recommendation.dart';
import '../../domain/repositories/hero_selection_repository.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_matcher.dart';
import '../../domain/services/recipe_readiness_service.dart';
import '../../domain/services/smart_recommendation_engine.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return const LocalRecipeRepository(LocalRecipeDataSource());
});

final recipesProvider = FutureProvider<List<Recipe>>((ref) {
  return ref.read(recipeRepositoryProvider).getRecipes();
});

final recipeReadinessServiceProvider = Provider<RecipeReadinessService?>((ref) {
  final registry = ref.watch(canonicalIngredientRegistryProvider);
  return registry == null
      ? null
      : RecipeReadinessService(
          registry: registry,
          unitEngine: ref.watch(unitConversionEngineProvider),
        );
});

class RecipeReadinessRequest {
  const RecipeReadinessRequest({required this.recipe, required this.servings});

  final Recipe recipe;
  final int servings;

  @override
  bool operator ==(Object other) {
    return other is RecipeReadinessRequest &&
        other.recipe.id == recipe.id &&
        other.servings == servings;
  }

  @override
  int get hashCode => Object.hash(recipe.id, servings);
}

final recipeReadinessProvider =
    Provider.family<RecipeReadiness?, RecipeReadinessRequest>((ref, request) {
      final service = ref.watch(recipeReadinessServiceProvider);
      if (service == null) {
        return null;
      }
      return service.evaluate(
        recipe: request.recipe,
        pantry: ref.watch(pantryProvider),
        servings: request.servings,
        evaluatedAt: ref.watch(appClockProvider).now(),
      );
    });

final recipeReadinessListProvider = FutureProvider<List<RecipeReadiness>>((
  ref,
) async {
  final service = ref.watch(recipeReadinessServiceProvider);
  if (service == null) {
    return const <RecipeReadiness>[];
  }
  final recipes = await ref.watch(recipesProvider.future);
  return service.evaluateAll(
    recipes: recipes,
    pantry: ref.watch(pantryProvider),
    evaluatedAt: ref.watch(appClockProvider).now(),
  );
});

final heroSelectionRepositoryProvider = Provider<HeroSelectionRepository>((
  ref,
) {
  return const LocalHeroSelectionRepository();
});

final recipeMatchesProvider = FutureProvider<List<RecipeMatch>>((ref) async {
  final recipes = await ref.watch(recipesProvider.future);
  final pantry = ref.watch(pantryProvider);

  return RecipeMatcher(
    registry: ref.watch(canonicalIngredientRegistryProvider),
  ).match(recipes: recipes, pantry: pantry);
});

class RecommendationSessionState {
  const RecommendationSessionState({this.pageIndex = 0, this.shuffleSeed = 0});

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

class HeroSelectionState {
  const HeroSelectionState({
    this.mode = HeroSelectionMode.automatic,
    this.key,
    this.reason,
  });

  final HeroSelectionMode mode;
  final String? key;
  final String? reason;

  bool get isAutomatic => mode == HeroSelectionMode.automatic;
  bool get isPinned => mode == HeroSelectionMode.pinned;
}

class HeroSelectionNotifier extends Notifier<HeroSelectionState> {
  HeroSelectionRepository get _repository {
    return ref.read(heroSelectionRepositoryProvider);
  }

  @override
  HeroSelectionState build() {
    try {
      final pinnedKey = _repository.loadPinnedIngredientKey();
      if (pinnedKey != null) {
        return HeroSelectionState(
          mode: HeroSelectionMode.pinned,
          key: pinnedKey,
        );
      }
    } on StateError {
      // Some isolated provider tests intentionally omit local persistence.
    }

    return const HeroSelectionState();
  }

  Future<void> useAutomatic() async {
    state = const HeroSelectionState();
    try {
      await _repository.clearPinnedIngredientKey();
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }

  Future<void> selectForSession(String key, {String? reason}) async {
    state = HeroSelectionState(
      mode: HeroSelectionMode.manual,
      key: key,
      reason: reason?.trim().isEmpty == true ? null : reason?.trim(),
    );
    try {
      await _repository.clearPinnedIngredientKey();
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }

  Future<void> pin(String key) async {
    state = HeroSelectionState(mode: HeroSelectionMode.pinned, key: key);
    try {
      await _repository.savePinnedIngredientKey(key);
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }
}

final heroSelectionProvider =
    NotifierProvider<HeroSelectionNotifier, HeroSelectionState>(
      HeroSelectionNotifier.new,
    );

final smartRecommendationProvider = Provider<AsyncValue<SmartRecommendation>>((
  ref,
) {
  final matches = ref.watch(recipeMatchesProvider);
  final pantry = ref.watch(pantryProvider);
  final heroSelection = ref.watch(heroSelectionProvider);
  final session = ref.watch(recommendationSessionProvider);

  return matches.whenData(
    (items) => const SmartRecommendationEngine().build(
      matches: items,
      pantry: pantry,
      selectedHeroKey: heroSelection.key,
      selectionMode: heroSelection.mode,
      selectionReason: heroSelection.reason,
      pageIndex: session.pageIndex,
      shuffleSeed: session.shuffleSeed,
      registry: ref.watch(canonicalIngredientRegistryProvider),
    ),
  );
});
