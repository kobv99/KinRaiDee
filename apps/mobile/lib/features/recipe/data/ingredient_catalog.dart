import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../core/domain/units/unit_contract.dart';

class IngredientCatalog {
  IngredientCatalog({
    AssetBundle? bundle,
    UnitConversionEngine? unitConversionEngine,
  }) : _bundle = bundle ?? rootBundle,
       _unitConversionEngine =
           unitConversionEngine ?? UnitConversionEngine.standard();

  final AssetBundle _bundle;
  final UnitConversionEngine _unitConversionEngine;

  Future<List<CanonicalIngredient>> load({
    String assetPath = 'assets/ingredients/thai_ingredients.json',
  }) async {
    final source = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(source) as List<dynamic>;

    return decoded
        .map((item) => _fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<CanonicalIngredientRegistry> loadRegistry({
    String assetPath = 'assets/ingredients/thai_ingredients.json',
  }) async {
    return CanonicalIngredientRegistry(
      ingredients: await load(assetPath: assetPath),
      redirects: defaultCanonicalIngredientRedirects,
    );
  }

  CanonicalIngredient? findByName(
    Iterable<CanonicalIngredient> ingredients,
    String value,
  ) {
    return CanonicalIngredientRegistry(
      ingredients: ingredients,
      redirects: _applicableRedirects(ingredients),
    ).resolve(value).ingredient;
  }

  CanonicalIngredient _fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final defaultUnit = json['defaultUnit']?.toString() ?? '';
    final inventoryUnit = _unitConversionEngine.resolveUnit(defaultUnit);
    if (inventoryUnit == null) {
      throw FormatException(
        'Canonical ingredient $id has unknown default unit "$defaultUnit".',
      );
    }
    final localized = <String, String>{
      if (name.isNotEmpty) 'th': name,
      ..._stringMap(json['localizedNames']),
    };
    final purchaseUnitId =
        json['defaultPurchaseUnitId']?.toString() ??
        switch (inventoryUnit.dimension) {
          'mass' => 'kilogram',
          'volume' => 'liter',
          _ => inventoryUnit.id,
        };
    final inventoryUnitId =
        json['defaultInventoryUnitId']?.toString() ?? inventoryUnit.id;
    if (_unitConversionEngine.resolveUnit(purchaseUnitId) == null ||
        _unitConversionEngine.resolveUnit(inventoryUnitId) == null) {
      throw FormatException(
        'Canonical ingredient $id references an unknown unit contract.',
      );
    }

    return CanonicalIngredient(
      id: id,
      canonicalName: json['canonicalName']?.toString() ?? name,
      localizedNames: localized,
      aliases: _stringList(json['aliases']),
      searchKeywords: <String>[
        ..._stringList(json['searchKeywords']),
        ..._stringList(json['tags']),
      ],
      category: json['category']?.toString() ?? 'other',
      defaultStorageType: _storageType(
        json['defaultStorageType']?.toString(),
        category: json['category']?.toString() ?? 'other',
      ),
      defaultPurchaseUnitId: purchaseUnitId,
      defaultInventoryUnitId: inventoryUnitId,
      parentId: json['parentId']?.toString(),
      metadata: IngredientMetadata(
        schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
        revision: _intValue(json['revision'], fallback: 1),
        source: json['source']?.toString() ?? 'thai_ingredients_v1',
      ),
    );
  }
}

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return <String, String>{
    for (final entry in value.entries)
      entry.key.toString(): entry.value.toString(),
  };
}

IngredientStorageType _storageType(String? value, {required String category}) {
  for (final type in IngredientStorageType.values) {
    if (type.name == value) {
      return type;
    }
  }
  return switch (category) {
    'protein' || 'seafood' => IngredientStorageType.refrigerated,
    'vegetable' || 'herb' => IngredientStorageType.refrigerated,
    'seasoning' || 'staple' => IngredientStorageType.pantry,
    _ => IngredientStorageType.ambient,
  };
}

int _intValue(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, String> _applicableRedirects(
  Iterable<CanonicalIngredient> ingredients,
) {
  final ids = ingredients.map((item) => item.id).toSet();
  return <String, String>{
    for (final entry in defaultCanonicalIngredientRedirects.entries)
      if (ids.contains(entry.key) && ids.contains(entry.value))
        entry.key: entry.value,
  };
}
