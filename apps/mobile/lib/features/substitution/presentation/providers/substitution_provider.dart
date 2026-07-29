import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/canonical_ingredient_providers.dart';
import '../../../../core/providers/pantry_provider.dart';
import '../../../recipe/domain/entities/recipe_readiness.dart';
import '../../data/knowledge_base_loader.dart';
import '../../data/local_ingredient_substitution_repository.dart';
import '../../domain/entities/ingredient_substitution.dart';
import '../../domain/repositories/ingredient_substitution_repository.dart';
import '../../domain/services/ingredient_substitution_service.dart';

final ingredientSubstitutionRepositoryProvider =
    Provider<IngredientSubstitutionRepository>(
      (ref) => LocalIngredientSubstitutionRepository(KnowledgeBaseLoader()),
    );

final ingredientSubstitutionServiceProvider =
    Provider<IngredientSubstitutionService?>((ref) {
      final registry = ref.watch(canonicalIngredientRegistryProvider);
      return registry == null
          ? null
          : IngredientSubstitutionService(
              repository: ref.watch(ingredientSubstitutionRepositoryProvider),
              registry: registry,
            );
    });

class RecipeSubstitutionRequest {
  const RecipeSubstitutionRequest({
    required this.recipeId,
    required this.candidates,
  });
  final String recipeId;
  final List<RecipeIngredientReadiness> candidates;

  @override
  bool operator ==(Object other) =>
      other is RecipeSubstitutionRequest &&
      recipeId == other.recipeId &&
      _ids(candidates) == _ids(other.candidates);

  @override
  int get hashCode => Object.hash(recipeId, _ids(candidates));

  static String _ids(List<RecipeIngredientReadiness> values) =>
      values.map((item) => item.canonicalIngredientId).join('|');
}

final recipeSubstitutionsProvider =
    FutureProvider.family<
      Map<String, List<IngredientSubstitutionRecommendation>>,
      RecipeSubstitutionRequest
    >((ref, request) async {
      final service = ref.watch(ingredientSubstitutionServiceProvider);
      if (service == null) return const {};
      final pantry = ref.watch(pantryProvider);
      final result = <String, List<IngredientSubstitutionRecommendation>>{};
      for (final candidate in request.candidates) {
        final recommendations = await service.recommend(
          originalIngredientId: candidate.canonicalIngredientId,
          pantry: pantry,
        );
        if (recommendations.isNotEmpty) {
          result[candidate.canonicalIngredientId] = recommendations;
        }
      }
      return Map.unmodifiable(result);
    });

class AcceptedSubstitutionsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void accept({
    required String recipeId,
    required String originalIngredientId,
    required String substituteIngredientId,
  }) {
    state = Map.unmodifiable({
      ...state,
      '$recipeId::$originalIngredientId': substituteIngredientId,
    });
  }
}

final acceptedSubstitutionsProvider =
    NotifierProvider<AcceptedSubstitutionsNotifier, Map<String, String>>(
      AcceptedSubstitutionsNotifier.new,
    );

Map<String, String> acceptedForRecipe(
  Map<String, String> accepted,
  String recipeId,
) {
  final prefix = '$recipeId::';
  return {
    for (final entry in accepted.entries)
      if (entry.key.startsWith(prefix))
        entry.key.substring(prefix.length): entry.value,
  };
}
