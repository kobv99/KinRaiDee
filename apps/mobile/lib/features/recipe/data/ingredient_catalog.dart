import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../core/domain/ingredients/ingredient_artwork_policy.dart';
import '../../../core/domain/units/ingredient_unit_policy.dart';
import '../../../core/domain/units/unit_contract.dart';
import 'pantry_catalog_canonical_definitions.dart';

class IngredientCatalog {
  IngredientCatalog({
    AssetBundle? bundle,
    UnitConversionEngine? unitConversionEngine,
    IngredientUnitPolicy? ingredientUnitPolicy,
    IngredientArtworkPolicy? ingredientArtworkPolicy,
  }) : _bundle = bundle ?? rootBundle,
       _unitConversionEngine =
           unitConversionEngine ?? UnitConversionEngine.standard(),
       _ingredientUnitPolicy =
           ingredientUnitPolicy ?? const IngredientUnitPolicy(),
       _ingredientArtworkPolicy =
           ingredientArtworkPolicy ?? const IngredientArtworkPolicy();

  final AssetBundle _bundle;
  final UnitConversionEngine _unitConversionEngine;
  final IngredientUnitPolicy _ingredientUnitPolicy;
  final IngredientArtworkPolicy _ingredientArtworkPolicy;

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
    final bundled = await load(assetPath: assetPath);
    return CanonicalIngredientRegistry(
      ingredients: applyPantryCatalogCanonicalCoverage(bundled),
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
    final category = json['category']?.toString() ?? 'other';
    final policyRecommendation = _ingredientUnitPolicy.forDefinition(
      canonicalId: id,
      category: category,
      defaultInventoryUnitId: inventoryUnitId,
      defaultPurchaseUnitId: purchaseUnitId,
      parentId: json['parentId']?.toString(),
    );
    final configuredRecommendedUnitIds = _stringList(
      json['recommendedUnitIds'],
    );
    final recommendedUnitIds =
        (configuredRecommendedUnitIds.isEmpty
                ? policyRecommendation.recommendedUnitIds
                : configuredRecommendedUnitIds)
            .map((value) {
              final unitId = _unitConversionEngine.resolveUnitId(value);
              if (unitId == null) {
                throw FormatException(
                  'Canonical ingredient $id recommends unknown unit "$value".',
                );
              }
              return unitId;
            })
            .toSet()
            .toList(growable: false);
    final preferredUnitId = _unitConversionEngine.resolveUnitId(
      json['preferredUnitId']?.toString() ??
          policyRecommendation.preferredUnitId,
    );
    if (preferredUnitId == null ||
        !recommendedUnitIds.contains(preferredUnitId)) {
      throw FormatException(
        'Canonical ingredient $id must recommend its preferred unit.',
      );
    }
    final unitFamily =
        _unitFamily(json['unitFamily']?.toString()) ??
        policyRecommendation.family;
    final configuredEmoji = json['emoji']?.toString().trim() ?? '';
    final emoji = configuredEmoji.isEmpty
        ? _ingredientArtworkPolicy.forDefinition(
            canonicalId: id,
            category: category,
          )
        : configuredEmoji;

    return CanonicalIngredient(
      id: id,
      canonicalName: json['canonicalName']?.toString() ?? name,
      localizedNames: localized,
      aliases: _stringList(json['aliases']),
      searchKeywords: <String>[
        ..._stringList(json['searchKeywords']),
        ..._stringList(json['tags']),
      ],
      category: category,
      defaultStorageType: _storageType(
        json['defaultStorageType']?.toString(),
        category: category,
      ),
      defaultPurchaseUnitId: purchaseUnitId,
      defaultInventoryUnitId: inventoryUnitId,
      emoji: emoji,
      preferredUnitId: preferredUnitId,
      recommendedUnitIds: recommendedUnitIds,
      unitFamily: unitFamily,
      parentId: json['parentId']?.toString(),
      trackingType:
          _trackingType(json['trackingType']?.toString()) ??
          _defaultTrackingType(category: category, unitFamily: unitFamily),
      perishable:
          _boolValue(json['perishable']) ??
          _storageType(
                json['defaultStorageType']?.toString(),
                category: category,
              ) ==
              IngredientStorageType.refrigerated,
      typicalShelfLifeDays:
          _nullableIntValue(json['typicalShelfLifeDays']) ??
          _defaultShelfLifeDays(category),
      substitutable: _boolValue(json['substitutable']) ?? true,
      recommendedStorage:
          json['recommendedStorage']?.toString() ??
          _storageType(
            json['defaultStorageType']?.toString(),
            category: category,
          ).name,
      metadata: IngredientMetadata(
        schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
        revision: _intValue(json['revision'], fallback: 1),
        source: json['source']?.toString() ?? 'thai_ingredients_v1',
      ),
    );
  }
}

IngredientTrackingType? _trackingType(String? value) {
  for (final type in IngredientTrackingType.values) {
    if (type.name == value) {
      return type;
    }
  }
  return null;
}

IngredientTrackingType _defaultTrackingType({
  required String category,
  required IngredientUnitFamily unitFamily,
}) {
  return switch (unitFamily) {
    IngredientUnitFamily.egg ||
    IngredientUnitFamily.canned => IngredientTrackingType.countBased,
    IngredientUnitFamily.meat ||
    IngredientUnitFamily.fish => IngredientTrackingType.weightBased,
    IngredientUnitFamily.liquid || IngredientUnitFamily.dryIngredient =>
      category == 'seasoning'
          ? IngredientTrackingType.stockBased
          : IngredientTrackingType.weightBased,
    IngredientUnitFamily.garlic ||
    IngredientUnitFamily.vegetable ||
    IngredientUnitFamily.tofu ||
    IngredientUnitFamily.generic => IngredientTrackingType.presenceOnly,
  };
}

int _defaultShelfLifeDays(String category) {
  return switch (category) {
    'protein' || 'seafood' => 3,
    'vegetable' || 'herb' => 7,
    'seasoning' => 365,
    'staple' => 180,
    _ => 30,
  };
}

IngredientUnitFamily? _unitFamily(String? value) {
  for (final family in IngredientUnitFamily.values) {
    if (family.name == value) {
      return family;
    }
  }
  return null;
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

int? _nullableIntValue(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

bool? _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return switch (value.toString().toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
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
