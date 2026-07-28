import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../pantry/application/inventory_transaction_providers.dart';
import '../../../recipe/presentation/providers/recipe_provider.dart';
import '../../../shopping/presentation/providers/shopping_recommendation_provider.dart';
import '../../domain/entities/pantry_insight.dart';
import '../../domain/services/pantry_insight_service.dart';

final pantryInsightServiceProvider = Provider<PantryInsightService?>((ref) {
  final registry = ref.watch(canonicalIngredientRegistryProvider);
  final readinessService = ref.watch(recipeReadinessServiceProvider);
  if (registry == null || readinessService == null) {
    return null;
  }
  return PantryInsightService(
    readinessService: readinessService,
    registry: registry,
  );
});

final pantryInsightProvider = FutureProvider<PantryInsight?>((ref) async {
  final service = ref.watch(pantryInsightServiceProvider);
  if (service == null) {
    return null;
  }

  final recipes = await ref.watch(recipesProvider.future);
  final recommendations = await ref.watch(
    shoppingRecommendationsProvider.future,
  );

  return service.analyze(
    pantry: ref.watch(pantryProvider),
    recipes: recipes,
    recommendations: recommendations,
    evaluatedAt: ref.watch(appClockProvider).now(),
  );
});
