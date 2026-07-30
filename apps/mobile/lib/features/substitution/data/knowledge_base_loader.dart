import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/entities/ingredient_substitution.dart';

class KnowledgeBaseLoader {
  KnowledgeBaseLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  static const assetPath = 'assets/substitutions/ingredient_substitutions.json';
  final AssetBundle _bundle;
  Future<List<IngredientSubstitution>>? _cache;

  Future<List<IngredientSubstitution>> load() => _cache ??= _load();

  Future<List<IngredientSubstitution>> _load() async {
    final root = jsonDecode(await _bundle.loadString(assetPath));
    if (root is! Map ||
        root['schemaVersion'] != 1 ||
        root['records'] is! List) {
      throw const FormatException('Invalid substitution knowledge base');
    }
    final ids = <String>{};
    final result = <IngredientSubstitution>[];
    for (final raw in root['records'] as List) {
      final json = Map<String, Object?>.from(raw as Map);
      String text(String key) {
        final value = json[key];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('Invalid $key');
        }
        return value.trim();
      }

      double score(String key) {
        final value = (json[key] as num?)?.toDouble();
        if (value == null || value < 0 || value > 1) {
          throw FormatException('Invalid $key');
        }
        return value;
      }

      List<String> texts(String key) =>
          (json[key] as List).map((item) => item.toString()).toList();
      final id = text('id');
      if (!ids.add(id)) throw FormatException('Duplicate $id');
      result.add(
        IngredientSubstitution(
          id: id,
          originalIngredientId: text('originalIngredientId'),
          substituteIngredientId: text('substituteIngredientId'),
          confidence: score('confidence'),
          flavorSimilarity: score('flavorSimilarity'),
          textureSimilarity: score('textureSimilarity'),
          cookingMethodCompatibility: score('cookingMethodCompatibility'),
          suitableDishes: texts('suitableDishes'),
          unsuitableDishes: texts('unsuitableDishes'),
          category: text('category'),
          notes: text('notes'),
          flavorDifference: text('flavorDifference'),
          textureDifference: text('textureDifference'),
          limitations: text('limitations'),
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
