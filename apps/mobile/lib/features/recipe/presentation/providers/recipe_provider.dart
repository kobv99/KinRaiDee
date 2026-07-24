import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/pantry_provider.dart';
import '../../../../core/services/storage_service.dart';
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
  @override
  HeroSelectionState build() {
    try {
      final pinnedKey = StorageService.loadPinnedHeroIngredientKey();
      if (pinnedKey != null) {
        return HeroSelectionState(
          mode: HeroSelectionMode.pinned,
          key: pinnedKey,
        );
      }
    } on StateError {
      // Some isolated provider tests do not initialize Hive.
    }

    return const HeroSelectionState();
  }

  Future<void> useAutomatic() async {
    state = const HeroSelectionState();
    try {
      await StorageService.clearPinnedHeroIngredientKey();
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
      await StorageService.clearPinnedHeroIngredientKey();
    } on StateError {
      // Storage is unavailable only in isolated tests.
    }
  }

  Future<void> pin(String key) async {
    state = HeroSelectionState(
      mode: HeroSelectionMode.pinned,
      key: key,
    );
    try {
      await StorageService.savePinnedHeroIngredientKey(key);
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
    ),
  );
});