import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../../application/shopping_providers.dart';
import '../../application/shopping_recommendation_controller.dart';
import '../../domain/entities/shopping_recommendation.dart';
import '../../domain/services/shopping_recommendation_service.dart';

final shoppingRecommendationServiceProvider =
    Provider<ShoppingRecommendationService?>((ref) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      final readinessService = ref.watch(recipeReadinessServiceProvider);
      if (registry == null || readinessService == null) {
        return null;
      }
      return ShoppingRecommendationService(
        readinessService: readinessService,
        registry: registry,
        unitEngine: ref.watch(unitConversionEngineProvider),
      );
    });

final shoppingRecommendationsProvider =
    FutureProvider<List<ShoppingRecommendation>>((ref) async {
      final service = ref.watch(shoppingRecommendationServiceProvider);
      if (service == null) {
        return const <ShoppingRecommendation>[];
      }
      final recipes = await ref.watch(recipesProvider.future);
      final shoppingLists = await ref.watch(shoppingListsProvider.future);
      return service.recommend(
        recipes: recipes,
        pantry: ref.watch(pantryProvider),
        shoppingLists: shoppingLists,
        evaluatedAt: ref.watch(appClockProvider).now(),
      );
    });

final shoppingRecommendationControllerProvider =
    Provider<ShoppingRecommendationController?>((ref) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      if (registry == null) {
        return null;
      }
      return ShoppingRecommendationController(
        repository: ref.watch(shoppingRepositoryProvider),
        registry: registry,
        unitEngine: ref.watch(unitConversionEngineProvider),
        executeMutation: ref.watch(shoppingMutationControllerProvider).execute,
        clock: ref.watch(appClockProvider),
      );
    });
