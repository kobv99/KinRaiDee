import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../pantry/presentation/providers/cooking_history_provider.dart';
import '../../../substitution/presentation/providers/substitution_provider.dart';
import '../../data/datasources/local_recipe_datasource.dart';
import '../../data/repositories/local_hero_selection_repository.dart';
import '../../data/repositories/local_recipe_repository.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_match.dart';
import '../../domain/entities/recipe_recommendation.dart';
import '../../domain/entities/recipe_readiness.dart';
import '../../domain/entities/smart_recommendation.dart';
import '../../domain/repositories/hero_selection_repository.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_candidate_service.dart';
import '../../domain/services/recipe_readiness_service.dart';
import '../../domain/services/recipe_recommendation_engine.dart';
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
        acceptedSubstitutions: acceptedForRecipe(
          ref.watch(acceptedSubstitutionsProvider),
          request.recipe.id,
        ),
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

class RecipeRecommendationQuery {
  const RecipeRecommendationQuery({
    this.filter = const RecommendationFilter(),
    this.sort = RecommendationSort.highestScore,
  });

  final RecommendationFilter filter;
  final RecommendationSort sort;
}

class RecipeRecommendationQueryNotifier
    extends Notifier<RecipeRecommendationQuery> {
  @override
  RecipeRecommendationQuery build() => const RecipeRecommendationQuery();

  void update({RecommendationFilter? filter, RecommendationSort? sort}) {
    state = RecipeRecommendationQuery(
      filter: filter ?? state.filter,
      sort: sort ?? state.sort,
    );
  }

  void reset() => state = const RecipeRecommendationQuery();
}

final recipeRecommendationQueryProvider =
    NotifierProvider<
      RecipeRecommendationQueryNotifier,
      RecipeRecommendationQuery
    >(RecipeRecommendationQueryNotifier.new);

final recipeRecommendationResultsProvider =
    FutureProvider<List<RecipeRecommendation>>((ref) async {
      final matches = await ref.watch(recipeMatchesProvider.future);
      final query = ref.watch(recipeRecommendationQueryProvider);
      return const RecipeRecommendationEngine().evaluateAll(
        matches: matches,
        pantry: ref.watch(pantryProvider),
        evaluatedAt: ref.watch(appClockProvider).now(),
        cookingHistory: ref.watch(cookingHistoryProvider),
        filter: query.filter,
        sort: query.sort,
      );
    });

final recipeRecommendationByIdProvider =
    Provider.family<AsyncValue<RecipeRecommendation?>, String>((ref, recipeId) {
      return ref
          .watch(recipeRecommendationResultsProvider)
          .whenData(
            (items) => items
                .where((item) => item.match.recipe.id == recipeId)
                .firstOrNull,
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
  final matches = ref
      .watch(recipeRecommendationResultsProvider)
      .whenData(
        (items) => items.map((item) => item.match).toList(growable: false),
      );
  final pantry = ref.watch(pantryProvider);
  final heroSelection = ref.watch(heroSelectionProvider);
  final session = ref.watch(recommendationSessionProvider);

  return matches.when(
    data: (items) => AsyncValue<SmartRecommendation>.data(
      const SmartRecommendationEngine().build(
        matches: items,
        pantry: pantry,
        selectedHeroKey: heroSelection.key,
        selectionMode: heroSelection.mode,
        selectionReason: heroSelection.reason,
        pageIndex: session.pageIndex,
        shuffleSeed: session.shuffleSeed,
        registry: ref.watch(canonicalIngredientRegistryProvider),
      ),
    ),
    loading: () => const AsyncValue<SmartRecommendation>.loading(),
    error: (error, stackTrace) => AsyncValue<SmartRecommendation>.error(
      const RecipeRecommendationUnavailable(),
      stackTrace,
    ),
  );
});
