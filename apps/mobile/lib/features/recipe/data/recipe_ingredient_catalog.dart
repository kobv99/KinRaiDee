import '../domain/entities/recipe_ingredient.dart';

class RecipeIngredientCatalog {
  RecipeIngredientCatalog._(this._definitions);

  factory RecipeIngredientCatalog.fromJson(Object? decoded) {
    if (decoded is! Map) {
      throw const FormatException('Invalid recipe ingredient catalog.');
    }
    final json = Map<String, dynamic>.from(decoded);
    final rows = json['ingredients'] as List<dynamic>? ?? const <dynamic>[];
    final definitions = <String, Map<String, dynamic>>{};
    for (final raw in rows) {
      final definition = Map<String, dynamic>.from(raw as Map);
      final id = definition['id']?.toString().trim() ?? '';
      if (id.isEmpty || definitions.containsKey(id)) {
        throw const FormatException('Invalid recipe ingredient definition.');
      }
      definitions[id] = Map<String, dynamic>.unmodifiable(definition);
    }
    return RecipeIngredientCatalog._(
      Map<String, Map<String, dynamic>>.unmodifiable(definitions),
    );
  }

  final Map<String, Map<String, dynamic>> _definitions;

  RecipeIngredient build(Object? raw) {
    final overrides = switch (raw) {
      String id => <String, dynamic>{'id': id},
      Map value => Map<String, dynamic>.from(value),
      _ => throw const FormatException('Invalid recipe ingredient.'),
    };
    final id =
        (overrides['id'] ?? overrides['canonicalIngredientId'])
            ?.toString()
            .trim() ??
        '';
    final definition = _definitions[id];
    if (definition == null) {
      throw const FormatException('Recipe ingredient is not configured.');
    }
    return RecipeIngredient.fromJson(<String, dynamic>{
      ...definition,
      ...overrides,
      'id': id,
    });
  }
}
