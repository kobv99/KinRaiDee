import '../../../../core/domain/ingredients/canonical_ingredient.dart';
import '../../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../../core/domain/units/unit_contract.dart';
import '../../../../core/models/ingredient.dart';
import '../models/pantry_quantity_transaction.dart';

enum PantryCanonicalMergeMode { add, addSeparate, replace }

class PantryCanonicalMergeResult {
  const PantryCanonicalMergeResult._({
    required this.pantry,
    required this.changes,
    required this.affectedIngredientIds,
    required this.canonicalIngredientId,
    required this.errorCode,
  });

  factory PantryCanonicalMergeResult.success({
    required List<Ingredient> pantry,
    required List<PantryQuantityChange> changes,
    required Set<String> affectedIngredientIds,
    required String canonicalIngredientId,
  }) {
    return PantryCanonicalMergeResult._(
      pantry: List<Ingredient>.unmodifiable(pantry),
      changes: List<PantryQuantityChange>.unmodifiable(changes),
      affectedIngredientIds: Set<String>.unmodifiable(affectedIngredientIds),
      canonicalIngredientId: canonicalIngredientId,
      errorCode: null,
    );
  }

  factory PantryCanonicalMergeResult.failure(String errorCode) {
    return PantryCanonicalMergeResult._(
      pantry: const <Ingredient>[],
      changes: const <PantryQuantityChange>[],
      affectedIngredientIds: const <String>{},
      canonicalIngredientId: '',
      errorCode: errorCode,
    );
  }

  final List<Ingredient> pantry;
  final List<PantryQuantityChange> changes;
  final Set<String> affectedIngredientIds;
  final String canonicalIngredientId;
  final String? errorCode;

  bool get isSuccess => errorCode == null;
}

class PantryCanonicalMergeService {
  const PantryCanonicalMergeService({
    required this.registry,
    required this.unitEngine,
  });

  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;

  PantryCanonicalMergeResult merge({
    required List<Ingredient> current,
    required Ingredient incoming,
    required PantryCanonicalMergeMode mode,
    required DateTime at,
    String? replaceIngredientId,
  }) {
    if (!incoming.quantity.isFinite || incoming.quantity < 0) {
      return PantryCanonicalMergeResult.failure('invalid_quantity');
    }
    if (mode == PantryCanonicalMergeMode.replace &&
        (replaceIngredientId == null || replaceIngredientId.trim().isEmpty)) {
      return PantryCanonicalMergeResult.failure(
        'missing_replaced_pantry_ingredient',
      );
    }

    final canonicalId = resolveCanonicalIngredientId(incoming);
    if (canonicalId == null) {
      return PantryCanonicalMergeResult.failure(
        'unknown_canonical_pantry_ingredient',
      );
    }
    final canonical = registry.byId(canonicalId)!;
    final incomingUnitId = _unitId(incoming);
    if (incomingUnitId == null) {
      return PantryCanonicalMergeResult.failure('unknown_inventory_unit');
    }

    final replacementId = replaceIngredientId?.trim();
    final original = replacementId == null
        ? null
        : current.where((item) => item.id == replacementId).firstOrNull;
    if (mode == PantryCanonicalMergeMode.replace && original == null) {
      return PantryCanonicalMergeResult.failure('pantry_lot_missing');
    }

    final candidates = current
        .where(
          (ingredient) =>
              ingredient.id != replacementId &&
              resolveCanonicalIngredientId(ingredient) == canonicalId,
        )
        .toList(growable: false);

    if (mode == PantryCanonicalMergeMode.addSeparate || candidates.isEmpty) {
      return _storeSingle(
        current: current,
        incoming: incoming,
        original: original,
        canonical: canonical,
        canonicalId: canonicalId,
        incomingUnitId: incomingUnitId,
        replacementId: replacementId,
        at: at,
      );
    }

    // Preserve the oldest durable Pantry record as the deterministic primary.
    // A purchase in another compatible unit must not change its identity, unit,
    // or metadata merely because the incoming item uses that unit.
    final sorted = List<Ingredient>.of(candidates)
      ..sort((first, second) {
        final created = first.createdAt.compareTo(second.createdAt);
        return created != 0 ? created : first.id.compareTo(second.id);
      });
    final primary = sorted.first;
    final targetUnitId = _unitId(primary);
    if (targetUnitId == null) {
      return PantryCanonicalMergeResult.failure('unknown_inventory_unit');
    }

    var total = 0.0;
    for (final candidate in candidates) {
      final unitId = _unitId(candidate);
      if (unitId == null) {
        return PantryCanonicalMergeResult.failure('unknown_inventory_unit');
      }
      final converted = unitEngine.tryConvert(
        candidate.quantity,
        fromUnit: unitId,
        toUnit: targetUnitId,
      );
      if (!converted.isSuccess) {
        return PantryCanonicalMergeResult.failure(
          'pantry_unit_conversion_required',
        );
      }
      total += converted.value!;
    }
    final incomingConverted = unitEngine.tryConvert(
      incoming.quantity,
      fromUnit: incomingUnitId,
      toUnit: targetUnitId,
    );
    if (!incomingConverted.isSuccess) {
      return PantryCanonicalMergeResult.failure(
        'pantry_unit_conversion_required',
      );
    }
    total += incomingConverted.value!;

    final afterQuantity = _round(total, targetUnitId);
    final allMerged = <Ingredient>[...candidates, incoming];
    final merged = Ingredient(
      id: primary.id,
      name: _preferredText(
        primary.name,
        incoming.name,
        canonical.displayName(),
      ),
      category: _preferredText(
        primary.category,
        incoming.category,
        canonical.category,
      ),
      emoji: _preferredText(primary.emoji, incoming.emoji, canonical.emoji),
      quantity: afterQuantity,
      unit: unitEngine.resolveUnit(targetUnitId)!.displayName,
      expiryDate: _mergedExpiry(allMerged, at),
      createdAt: primary.createdAt,
      updatedAt: at,
      isFavorite: allMerged.any((ingredient) => ingredient.isFavorite),
      canonicalIngredientId: canonicalId,
      canonicalUnitId: targetUnitId,
      canonicalMappingStatus: CanonicalMappingStatus.mapped,
    );

    final removedIds = <String>{
      ...candidates.map((ingredient) => ingredient.id),
      if (replacementId != null) replacementId,
    };
    final pantry = _replaceAtFirstAffected(
      current,
      removedIds: removedIds,
      replacement: merged,
    );
    final affectedIds = <String>{...removedIds, merged.id};
    final changes = _changes(
      before: current,
      after: pantry,
      affectedIds: affectedIds,
      canonicalId: canonicalId,
    );
    return PantryCanonicalMergeResult.success(
      pantry: pantry,
      changes: changes,
      affectedIngredientIds: affectedIds,
      canonicalIngredientId: canonicalId,
    );
  }

  String? resolveCanonicalIngredientId(Ingredient ingredient) {
    final rawCanonicalId = ingredient.canonicalIngredientId.trim();
    return registry.canonicalIdFor(rawCanonicalId) ??
        registry.resolve(rawCanonicalId).ingredient?.id ??
        registry.resolve(ingredient.name).ingredient?.id;
  }

  PantryCanonicalMergeResult _storeSingle({
    required List<Ingredient> current,
    required Ingredient incoming,
    required Ingredient? original,
    required CanonicalIngredient canonical,
    required String canonicalId,
    required String incomingUnitId,
    required String? replacementId,
    required DateTime at,
  }) {
    final recordId = replacementId ?? incoming.id;
    if (recordId.trim().isEmpty) {
      return PantryCanonicalMergeResult.failure(
        'missing_pantry_ingredient_id',
      );
    }
    if (replacementId == null &&
        current.any((ingredient) => ingredient.id == recordId)) {
      return PantryCanonicalMergeResult.failure('duplicate_pantry_ingredient_id');
    }
    final stored = Ingredient(
      id: recordId,
      name: _preferredText(incoming.name, canonical.displayName()),
      category: _preferredText(incoming.category, canonical.category),
      emoji: _preferredText(incoming.emoji, canonical.emoji),
      quantity: _round(incoming.quantity, incomingUnitId),
      unit: unitEngine.resolveUnit(incomingUnitId)!.displayName,
      expiryDate: incoming.expiryDate,
      createdAt: original?.createdAt ?? incoming.createdAt,
      updatedAt: at,
      isFavorite: incoming.isFavorite || (original?.isFavorite ?? false),
      canonicalIngredientId: canonicalId,
      canonicalUnitId: incomingUnitId,
      canonicalMappingStatus: CanonicalMappingStatus.mapped,
    );
    final affectedIds = <String>{recordId};
    final pantry = replacementId == null
        ? <Ingredient>[...current, stored]
        : current
              .map(
                (ingredient) =>
                    ingredient.id == replacementId ? stored : ingredient,
              )
              .toList(growable: false);
    final changes = _changes(
      before: current,
      after: pantry,
      affectedIds: affectedIds,
      canonicalId: canonicalId,
    );
    return PantryCanonicalMergeResult.success(
      pantry: pantry,
      changes: changes,
      affectedIngredientIds: affectedIds,
      canonicalIngredientId: canonicalId,
    );
  }

  String? _unitId(Ingredient ingredient) {
    return unitEngine.resolveUnitId(
      ingredient.canonicalUnitId.trim().isEmpty
          ? ingredient.unit
          : ingredient.canonicalUnitId,
    );
  }

  List<Ingredient> _replaceAtFirstAffected(
    List<Ingredient> current, {
    required Set<String> removedIds,
    required Ingredient replacement,
  }) {
    final result = <Ingredient>[];
    var inserted = false;
    for (final ingredient in current) {
      if (!removedIds.contains(ingredient.id)) {
        result.add(ingredient);
        continue;
      }
      if (!inserted) {
        result.add(replacement);
        inserted = true;
      }
    }
    if (!inserted) {
      result.add(replacement);
    }
    return List<Ingredient>.unmodifiable(result);
  }

  List<PantryQuantityChange> _changes({
    required List<Ingredient> before,
    required List<Ingredient> after,
    required Set<String> affectedIds,
    required String canonicalId,
  }) {
    final beforeById = {
      for (final ingredient in before) ingredient.id: ingredient,
    };
    final afterById = {
      for (final ingredient in after) ingredient.id: ingredient,
    };
    final result = <PantryQuantityChange>[];
    for (final id in affectedIds.toList()..sort()) {
      final previous = beforeById[id];
      final next = afterById[id];
      final identity = next ?? previous;
      if (identity == null) {
        continue;
      }
      result.add(
        PantryQuantityChange(
          ingredientId: id,
          ingredientName: identity.name,
          unit: identity.unit,
          beforeQuantity: previous?.quantity ?? 0,
          afterQuantity: next?.quantity ?? 0,
          canonicalIngredientId: canonicalId,
          canonicalUnitId:
              next?.canonicalUnitId ?? previous?.canonicalUnitId ?? '',
        ),
      );
    }
    return List<PantryQuantityChange>.unmodifiable(result);
  }

  DateTime? _mergedExpiry(List<Ingredient> ingredients, DateTime at) {
    if (ingredients.any((ingredient) => ingredient.isExpiredAt(at))) {
      return null;
    }
    final expiries = ingredients
        .map((ingredient) => ingredient.expiryDate)
        .whereType<DateTime>()
        .toSet();
    return expiries.length == 1 ? expiries.single : null;
  }

  double _round(double quantity, String unitId) {
    return unitEngine.precisionPolicy.apply(
      quantity,
      decimalPlaces: unitEngine.resolveUnit(unitId)?.decimalPlaces,
    );
  }
}

String _preferredText(String first, [String second = '', String third = '']) {
  for (final value in <String>[first, second, third]) {
    if (value.trim().isNotEmpty) {
      return value;
    }
  }
  return '';
}
