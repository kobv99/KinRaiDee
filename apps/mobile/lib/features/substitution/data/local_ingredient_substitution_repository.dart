import '../domain/entities/ingredient_substitution.dart';
import '../domain/repositories/ingredient_substitution_repository.dart';
import 'knowledge_base_loader.dart';

class LocalIngredientSubstitutionRepository
    implements IngredientSubstitutionRepository {
  LocalIngredientSubstitutionRepository(this.loader);
  final KnowledgeBaseLoader loader;

  @override
  Future<List<IngredientSubstitution>> getAll() => loader.load();
}
