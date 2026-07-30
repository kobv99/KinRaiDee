import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/models/ingredient.dart';
import '../entities/ingredient_substitution.dart';
import '../repositories/ingredient_substitution_repository.dart';
import 'substitution_ranking_service.dart';

class IngredientSubstitutionService {
  const IngredientSubstitutionService({
    required this.repository,
    required this.registry,
    this.rankingService = const SubstitutionRankingService(),
  });

  final IngredientSubstitutionRepository repository;
  final CanonicalIngredientRegistry registry;
  final SubstitutionRankingService rankingService;

  Future<List<IngredientSubstitutionRecommendation>> recommend({
    required String originalIngredientId,
    required List<Ingredient> pantry,
  }) async {
    final original = registry.canonicalIdFor(originalIngredientId);
    if (original == null) return const [];
    final records = await repository.getAll();
    final pantryIds = pantry
        .where((item) => item.quantity > 0)
        .map((item) => registry.canonicalIdFor(item.canonicalIngredientId))
        .whereType<String>()
        .toSet();
    return rankingService.rank(
      substitutions: records
          .where((item) => item.originalIngredientId == original)
          .toList(),
      pantryCanonicalIds: pantryIds,
    );
  }
}
