import 'package:hive_flutter/hive_flutter.dart';

import '../../features/pantry/domain/models/cooking_history_entry.dart';
import '../models/ingredient.dart';

class StorageService {
  StorageService._();

  static const String pantryBoxName = 'pantry_box';
  static const String ingredientsKey = 'ingredients';
  static const String favoriteIngredientNamesKey = 'favorite_ingredient_names';
  static const String pinnedHeroIngredientKey = 'pinned_hero_ingredient_key';
  static const String cookingHistoryKey = 'cooking_history';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(pantryBoxName);
  }

  static Box<dynamic> get _pantryBox {
    if (!Hive.isBoxOpen(pantryBoxName)) {
      throw StateError(
        'StorageService has not been initialized. '
        'Call StorageService.init() before using the storage.',
      );
    }

    return Hive.box<dynamic>(pantryBoxName);
  }

  static Future<void> saveIngredients(List<Ingredient> ingredients) async {
    final data = ingredients
        .map<Map<String, dynamic>>(_ingredientToMap)
        .toList(growable: false);

    await _pantryBox.put(ingredientsKey, data);
  }

  static List<Ingredient> loadIngredients() {
    final rawData = _pantryBox.get(ingredientsKey, defaultValue: <dynamic>[]);

    if (rawData is! List) {
      return <Ingredient>[];
    }

    final ingredients = <Ingredient>[];

    for (final item in rawData) {
      final ingredient = _ingredientFromDynamic(item);

      if (ingredient != null) {
        ingredients.add(ingredient);
      }
    }

    return List<Ingredient>.unmodifiable(ingredients);
  }

  static Set<String> loadFavoriteIngredientNames() {
    final rawData = _pantryBox.get(
      favoriteIngredientNamesKey,
      defaultValue: <dynamic>[],
    );

    if (rawData is! List) {
      return <String>{};
    }

    return rawData
        .map((item) => normalizeIngredientName(item.toString()))
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  static Future<void> saveFavoriteIngredientNames(Set<String> names) async {
    final normalizedNames =
        names
            .map(normalizeIngredientName)
            .where((name) => name.isNotEmpty)
            .toList(growable: false)
          ..sort();

    await _pantryBox.put(favoriteIngredientNamesKey, normalizedNames);
  }

  static String? loadPinnedHeroIngredientKey() {
    final value = _pantryBox.get(pinnedHeroIngredientKey);
    final normalized = normalizeIngredientName(value?.toString() ?? '');
    return normalized.isEmpty ? null : normalized;
  }

  static Future<void> savePinnedHeroIngredientKey(String key) async {
    final normalized = normalizeIngredientName(key);
    if (normalized.isEmpty) {
      await clearPinnedHeroIngredientKey();
      return;
    }

    await _pantryBox.put(pinnedHeroIngredientKey, normalized);
  }

  static Future<void> clearPinnedHeroIngredientKey() async {
    await _pantryBox.delete(pinnedHeroIngredientKey);
  }

  static List<CookingHistoryEntry> loadCookingHistory() {
    final rawData = _pantryBox.get(
      cookingHistoryKey,
      defaultValue: <dynamic>[],
    );
    if (rawData is! List) {
      return <CookingHistoryEntry>[];
    }

    final entries = <CookingHistoryEntry>[];
    for (final item in rawData) {
      if (item is! Map) {
        continue;
      }

      try {
        final entry = CookingHistoryEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (entry.id.isNotEmpty && entry.recipeName.isNotEmpty) {
          entries.add(entry);
        }
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }

    entries.sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return List<CookingHistoryEntry>.unmodifiable(entries);
  }

  static Future<void> saveCookingHistory(
    List<CookingHistoryEntry> entries,
  ) async {
    final data = entries
        .map<Map<String, dynamic>>((entry) => entry.toJson())
        .toList(growable: false);
    await _pantryBox.put(cookingHistoryKey, data);
  }

  static String normalizeIngredientName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<void> clearIngredients() async {
    await _pantryBox.delete(ingredientsKey);
  }

  static Map<String, dynamic> _ingredientToMap(Ingredient ingredient) {
    return <String, dynamic>{
      'id': ingredient.id,
      'name': ingredient.name,
      'category': ingredient.category,
      'emoji': ingredient.emoji,
      'quantity': ingredient.quantity,
      'unit': ingredient.unit,
      'expiryDate': ingredient.expiryDate?.toIso8601String(),
      'createdAt': ingredient.createdAt.toIso8601String(),
      'updatedAt': ingredient.updatedAt.toIso8601String(),
      'isFavorite': ingredient.isFavorite,
    };
  }

  static Ingredient? _ingredientFromDynamic(dynamic rawItem) {
    if (rawItem is! Map) {
      return null;
    }

    try {
      final map = Map<String, dynamic>.from(rawItem);

      final createdAt = _parseDateTime(map['createdAt']) ?? DateTime.now();
      final updatedAt = _parseDateTime(map['updatedAt']) ?? createdAt;

      return Ingredient(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        category: map['category']?.toString() ?? 'อื่น ๆ',
        emoji: map['emoji']?.toString() ?? '🍽️',
        quantity: _parseDouble(map['quantity']),
        unit: map['unit']?.toString() ?? 'ชิ้น',
        expiryDate: _parseDateTime(map['expiryDate']),
        createdAt: createdAt,
        updatedAt: updatedAt,
        isFavorite: _parseBool(map['isFavorite']),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
