enum RecipeIngredientRole { primary, secondary, optional }

enum RecipeIngredientImportance { main, supporting, garnish }

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.required = true,
    this.aliases = const <String>[],
    this.role,
    this.importance,
    double? weight,
    double? readinessWeight,
  }) : readinessWeight = weight ?? readinessWeight,
       assert(weight == null || weight > 0),
       assert(readinessWeight == null || readinessWeight > 0);

  final String id;
  final String name;
  final double quantity;
  final String unit;

  /// Legacy compatibility flag. New Recipe data should declare [role].
  final bool required;
  final List<String> aliases;

  /// Product role declared by Recipe data.
  final RecipeIngredientRole? role;

  /// Legacy compatibility field. New Recipe data should use [role].
  final RecipeIngredientImportance? importance;

  /// Explicit data-driven contribution to Recipe Readiness.
  ///
  /// JSON accepts both `weight` and the legacy `readinessWeight` key.
  final double? readinessWeight;

  double? get weight => readinessWeight;

  String get canonicalIngredientId => id;

  RecipeIngredientRole effectiveRole({bool isHero = false}) {
    final declaredRole = role;
    if (declaredRole != null) {
      return declaredRole;
    }
    switch (importance) {
      case RecipeIngredientImportance.main:
        return RecipeIngredientRole.primary;
      case RecipeIngredientImportance.supporting:
        return RecipeIngredientRole.secondary;
      case RecipeIngredientImportance.garnish:
        return RecipeIngredientRole.optional;
      case null:
        break;
    }
    if (!required) {
      return RecipeIngredientRole.optional;
    }
    return isHero
        ? RecipeIngredientRole.primary
        : RecipeIngredientRole.secondary;
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    final role = recipeIngredientRoleFromJson(json['role']);
    return RecipeIngredient(
      id: (json['canonicalIngredientId'] ?? json['id'])?.toString() ?? '',
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      required:
          json['required'] as bool? ?? role != RecipeIngredientRole.optional,
      aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[])
          .map((alias) => alias.toString())
          .toList(growable: false),
      role: role,
      importance: _importance(json['importance']),
      weight: _positiveWeight(json['weight'] ?? json['readinessWeight']),
    );
  }
}

RecipeIngredientRole? recipeIngredientRoleFromJson(Object? value) {
  final name = value?.toString().trim().toLowerCase();
  if (name == null || name.isEmpty) {
    return null;
  }
  return switch (name) {
    'primary' || 'main' || 'hero' => RecipeIngredientRole.primary,
    'secondary' || 'supporting' || 'required' => RecipeIngredientRole.secondary,
    'optional' || 'garnish' => RecipeIngredientRole.optional,
    _ => null,
  };
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
