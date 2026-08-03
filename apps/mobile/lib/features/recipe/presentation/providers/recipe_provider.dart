import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../data/datasources/local_recipe_datasource.dart';
import '../../data/repositories/local_hero_selection_repository.dart';
import '../../data/repositories/local_recipe_repository.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_compatibility.dart';
import '../../domain/entities/recipe_match.dart';
import '../../domain/entities/recipe_readiness.dart';
import '../../domain/entities/smart_recommendation.dart';
import '../../domain/repositories/hero_selection_repository.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_candidate_service.dart';
import '../../domain/services/main_ingredient_compatibility_service.dart';
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

final recipeCandidateServiceProvider = Provider<RecipeCandidateService?>((ref) {
  final readinessService = ref.watch(recipeReadinessServiceProvider);
  return readinessService == null
      ? null
      : RecipeCandidateService(readinessService: readinessService);
});

class RecipeReadinessRequest {
  const RecipeReadinessRequest({required this.recipe, required this.servings});

  final Recipe recipe;
  final int servings;

  @override
  bool operator ==(Object other) {
    return other is RecipeReadinessRequest &&
        other.recipe.id == recipe.id &&
        other.recipe.version == recipe.version &&
        other.servings == servings;
  }

  @override
  int get hashCode => Object.hash(recipe.id, recipe.version, servings);
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
  final service = ref.watch(recipeCandidateServiceProvider);
  if (service == null) {
    return const <RecipeMatch>[];
  }
  final recipes = await ref.watch(recipesProvider.future);
  return service.findCandidates(
    recipes: recipes,
    pantry: ref.watch(pantryProvider),
    evaluatedAt: ref.watch(appClockProvider).now(),
  );
});

/// Full readiness projection used by recipe exploration and manual main-
/// ingredient selection. Unlike [recipeMatchesProvider], this intentionally
/// includes recipes whose primary ingredient is not currently in Pantry.
final allRecipeMatchesProvider = FutureProvider<List<RecipeMatch>>((ref) async {
  final service = ref.watch(recipeCandidateServiceProvider);
  if (service == null) {
    return const <RecipeMatch>[];
  }
  final recipes = await ref.watch(recipesProvider.future);
  return service.evaluateAllRecipes(
    recipes: recipes,
    pantry: ref.watch(pantryProvider),
    evaluatedAt: ref.watch(appClockProvider).now(),
  );
});

final mainIngredientCompatibilityServiceProvider =
    Provider<MainIngredientCompatibilityService>((ref) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      if (registry == null) {
        return const MainIngredientCompatibilityService();
      }

      return MainIngredientCompatibilityService(
        config: MainIngredientCompatibilityConfig(
          profiles: <String, IngredientCompatibilityProfile>{
            for (final ingredient in registry.ingredients)
              ingredient.id: IngredientCompatibilityProfile(
                forms: ingredient.ingredientForms,
                textures: ingredient.textures,
                cookingMethods: ingredient.supportedCookingMethods,
                familyIds: registry
                    .ancestorIdsFor(ingredient.id)
                    .toList(growable: false),
              ),
          },
        ),
      );
    });

final smartRecommendationEngineProvider = Provider<SmartRecommendationEngine>((
  ref,
) {
  return SmartRecommendationEngine(
    compatibilityService: ref.watch(mainIngredientCompatibilityServiceProvider),
  );
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
    this.recentKeys = const <String>[],
  });

  final HeroSelectionMode mode;
  final String? key;
  final String? reason;
  final List<String> recentKeys;

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
    state = HeroSelectionState(recentKeys: state.recentKeys);
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
      recentKeys: _withRecent(key),
    );
    try {
      await _repository.clearPinnedIngredientKey();
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }

  Future<void> pin(String key) async {
    state = HeroSelectionState(
      mode: HeroSelectionMode.pinned,
      key: key,
      recentKeys: _withRecent(key),
    );
    try {
      await _repository.savePinnedIngredientKey(key);
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }

  List<String> _withRecent(String key) {
    return List<String>.unmodifiable(
      <String>[key, ...state.recentKeys.where((item) => item != key)].take(6),
    );
  }
}

final heroSelectionProvider =
    NotifierProvider<HeroSelectionNotifier, HeroSelectionState>(
      HeroSelectionNotifier.new,
    );

class RecipeRecommendationUnavailable implements Exception {
  const RecipeRecommendationUnavailable();

  @override
  String toString() {
    return 'โหลดคำแนะนำจาก Pantry ไม่สำเร็จ กรุณาลองอีกครั้ง';
  }
}

final smartRecommendationProvider = Provider<AsyncValue<SmartRecommendation>>((
  ref,
) {
  final matches = ref.watch(recipeMatchesProvider);
  final allMatches = ref.watch(allRecipeMatchesProvider);
  final pantry = ref.watch(pantryProvider);
  final heroSelection = ref.watch(heroSelectionProvider);
  final session = ref.watch(recommendationSessionProvider);

  return matches.when(
    data: (items) => allMatches.when(
      data: (allItems) => AsyncValue<SmartRecommendation>.data(
        ref
            .watch(smartRecommendationEngineProvider)
            .build(
              matches: items,
              allRecipeMatches: allItems,
              pantry: pantry,
              selectedHeroKey: heroSelection.key,
              selectionMode: heroSelection.mode,
              selectionReason: heroSelection.reason,
              pageIndex: session.pageIndex,
              shuffleSeed: session.shuffleSeed,
              registry: ref.watch(canonicalIngredientRegistryProvider),
              recentHeroKeys: heroSelection.recentKeys.toSet(),
            ),
      ),
      loading: () => const AsyncValue<SmartRecommendation>.loading(),
      error: (error, stackTrace) => AsyncValue<SmartRecommendation>.error(
        const RecipeRecommendationUnavailable(),
        stackTrace,
      ),
    ),
    loading: () => const AsyncValue<SmartRecommendation>.loading(),
    error: (error, stackTrace) => AsyncValue<SmartRecommendation>.error(
      const RecipeRecommendationUnavailable(),
      stackTrace,
    ),
  );
});
