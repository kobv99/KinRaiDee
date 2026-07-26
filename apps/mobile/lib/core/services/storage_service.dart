import 'package:hive_flutter/hive_flutter.dart';

import '../../features/pantry/domain/models/cooking_history_entry.dart';
import '../../features/pantry/domain/models/inventory_state_envelope.dart';
import '../models/ingredient.dart';

class StorageService {
  StorageService._();

  static const String pantryBoxName = 'pantry_box';
  static const String ingredientsKey = 'ingredients';
  static const String favoriteIngredientNamesKey = 'favorite_ingredient_names';
  static const String pinnedHeroIngredientKey = 'pinned_hero_ingredient_key';
  static const String cookingHistoryKey = 'cooking_history';
  static const String inventoryEnvelopeKey = 'inventory_state_envelope_v1';

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

  static List<Ingredient> loadIngredients() {
    final envelope = loadInventoryEnvelope();
    if (envelope != null) {
      return envelope.pantry;
    }
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
    final envelope = loadInventoryEnvelope();
    if (envelope != null) {
      return envelope.history;
    }
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

    entries.sort(
      (first, second) => second.createdAt.compareTo(first.createdAt),
    );
    return List<CookingHistoryEntry>.unmodifiable(entries);
  }

  static InventoryStateEnvelope? loadInventoryEnvelope() {
    final raw = _pantryBox.get(inventoryEnvelopeKey);
    if (raw == null) {
      return null;
    }
    if (raw is! Map) {
      throw const FormatException('Inventory envelope is not a map.');
    }
    final envelope = InventoryStateEnvelope.fromJson(
      Map<String, dynamic>.from(raw),
    );
    if (!envelope.hasValidChecksum) {
      throw const FormatException('Inventory envelope checksum is invalid.');
    }
    return envelope;
  }

  static String normalizeIngredientName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Ingredient? _ingredientFromDynamic(dynamic rawItem) {
    if (rawItem is! Map) {
      return null;
    }

    try {
      final map = Map<String, dynamic>.from(rawItem);

      final createdAt =
          _parseDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
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
