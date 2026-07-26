class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const <String>[],
    this.defaultUnit = '',
    this.parentId,
    this.tags = const <String>[],
  });

  final String id;
  final String name;
  final String category;
  final List<String> aliases;
  final String defaultUnit;
  final String? parentId;
  final List<String> tags;

  Iterable<String> get searchableNames sync* {
    yield name;
    yield* aliases;
  }

  bool matches(String value) {
    final normalized = _normalize(value);
    return searchableNames.any((item) => _normalize(item) == normalized);
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'other',
      aliases: _stringList(json['aliases']),
      defaultUnit: json['defaultUnit'] as String? ?? '',
      parentId: json['parentId'] as String?,
      tags: _stringList(json['tags']),
    );
  }
}

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
