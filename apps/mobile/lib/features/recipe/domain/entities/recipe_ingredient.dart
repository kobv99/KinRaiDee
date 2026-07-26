class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.required = true,
    this.aliases = const <String>[],
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool required;
  final List<String> aliases;

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
    );
  }
}
