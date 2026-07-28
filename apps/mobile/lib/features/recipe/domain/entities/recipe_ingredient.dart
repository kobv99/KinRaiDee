enum RecipeIngredientImportance { main, supporting, garnish }

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.required = true,
    this.aliases = const <String>[],
    this.importance,
    this.readinessWeight,
  }) : assert(readinessWeight == null || readinessWeight > 0);

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool required;
  final List<String> aliases;

  /// Optional semantic importance used by Recipe Readiness.
  ///
  /// Existing Recipe packs remain compatible because the readiness service
  /// derives a default from hero/required/optional status when this is null.
  final RecipeIngredientImportance? importance;

  /// Optional explicit scoring weight. This overrides the default importance
  /// policy without coupling Recipe data to presentation percentages.
  final double? readinessWeight;

  String get canonicalIngredientId => id;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: (json['canonicalIngredientId'] ?? json['id'])?.toString() ?? '',
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      required: json['required'] as bool? ?? true,
      aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[])
          .map((alias) => alias.toString())
          .toList(growable: false),
      importance: _importance(json['importance']),
      readinessWeight: _positiveWeight(json['readinessWeight']),
    );
  }
}

RecipeIngredientImportance? _importance(Object? value) {
  final name = value?.toString().trim();
  if (name == null || name.isEmpty) {
    return null;
  }
  for (final importance in RecipeIngredientImportance.values) {
    if (importance.name == name) {
      return importance;
    }
  }
  return null;
}

double? _positiveWeight(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
}
