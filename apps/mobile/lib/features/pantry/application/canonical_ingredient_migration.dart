import '../../../core/domain/ingredients/canonical_ingredient_registry.dart';
import '../../../core/domain/units/unit_contract.dart';
import '../../../core/models/ingredient.dart';
import '../domain/models/cooking_history_entry.dart';

const int canonicalIngredientMigrationVersion = 2;

enum IngredientMigrationIssueType {
  unknownIngredient,
  ambiguousIngredient,
  unknownUnit,
}

class IngredientMigrationIssue {
  const IngredientMigrationIssue({
    required this.type,
    required this.recordId,
    required this.value,
    this.candidateIds = const <String>[],
  });

  final IngredientMigrationIssueType type;
  final String recordId;
  final String value;
  final List<String> candidateIds;
}

class CanonicalIngredientMigrationResult {
  const CanonicalIngredientMigrationResult({
    required this.pantry,
    required this.history,
    required this.issues,
    required this.mappedCount,
    required this.unmappedCount,
    required this.changed,
  });

  final List<Ingredient> pantry;
  final List<CookingHistoryEntry> history;
  final List<IngredientMigrationIssue> issues;
  final int mappedCount;
  final int unmappedCount;
  final bool changed;
}

class CanonicalIngredientMigration {
  const CanonicalIngredientMigration({
    required this.registry,
    required this.unitEngine,
  });

  final CanonicalIngredientRegistry registry;
  final UnitConversionEngine unitEngine;

  CanonicalIngredientMigrationResult migrate({
    required List<Ingredient> pantry,
    required List<CookingHistoryEntry> history,
  }) {
    final issues = <IngredientMigrationIssue>[];
    final migratedPantry = <Ingredient>[];
    final pantryByLotId = <String, Ingredient>{};
    var mappedCount = 0;
    var unmappedCount = 0;
    var changed = false;

    for (final ingredient in pantry) {
      final migrated = migratePantryIngredient(ingredient, issues: issues);
      migratedPantry.add(migrated);
      pantryByLotId[migrated.id] = migrated;
      if (migrated.canonicalMappingStatus == CanonicalMappingStatus.mapped) {
        mappedCount++;
      } else {
        unmappedCount++;
      }
      changed =
          changed ||
          migrated.toJson().toString() != ingredient.toJson().toString();
    }

    final migratedHistory = history
        .map((entry) {
          var entryChanged =
              entry.schemaVersion < canonicalIngredientMigrationVersion;
          final changes = entry.changes
              .map((change) {
                final pantryIngredient = pantryByLotId[change.ingredientId];
                final migrated = pantryIngredient == null
                    ? _migrateHistoryChange(change, entry.id, issues)
                    : change.copyWith(
                        canonicalIngredientId:
                            pantryIngredient.canonicalIngredientId,
                        canonicalUnitId: pantryIngredient.canonicalUnitId,
                        canonicalMappingStatus:
                            pantryIngredient.canonicalMappingStatus,
                      );
                entryChanged =
                    entryChanged ||
                    migrated.toJson().toString() != change.toJson().toString();
                return migrated;
              })
              .toList(growable: false);
          changed = changed || entryChanged;
          return entry.copyWith(
            schemaVersion: canonicalIngredientMigrationVersion,
            changes: changes,
          );
        })
        .toList(growable: false);

    return CanonicalIngredientMigrationResult(
      pantry: List<Ingredient>.unmodifiable(migratedPantry),
      history: List<CookingHistoryEntry>.unmodifiable(migratedHistory),
      issues: List<IngredientMigrationIssue>.unmodifiable(issues),
      mappedCount: mappedCount,
      unmappedCount: unmappedCount,
      changed: changed,
    );
  }

  Ingredient migratePantryIngredient(
    Ingredient ingredient, {
    List<IngredientMigrationIssue>? issues,
  }) {
    final resolution = registry.resolve(
      ingredient.name,
      preferredId: ingredient.canonicalIngredientId,
    );
    final canonical = resolution.ingredient;
    final canonicalIngredientId =
        canonical?.id ?? registry.unmappedIdFor(ingredient.name);
    final mappingStatus = canonical == null
        ? CanonicalMappingStatus.unmapped
        : CanonicalMappingStatus.mapped;
    if (canonical == null) {
      issues?.add(
        IngredientMigrationIssue(
          type: resolution.matchType == CanonicalMatchType.ambiguous
              ? IngredientMigrationIssueType.ambiguousIngredient
              : IngredientMigrationIssueType.unknownIngredient,
          recordId: ingredient.id,
          value: ingredient.name,
          candidateIds: resolution.candidateIds,
        ),
      );
    }

    final resolvedUnit =
        unitEngine.resolveUnitId(ingredient.canonicalUnitId) ??
        unitEngine.resolveUnitId(ingredient.unit);
    final canonicalUnitId =
        resolvedUnit ??
        canonical?.defaultInventoryUnitId ??
        registry.unmappedIdFor('unit:${ingredient.unit}');
    if (resolvedUnit == null) {
      issues?.add(
        IngredientMigrationIssue(
          type: IngredientMigrationIssueType.unknownUnit,
          recordId: ingredient.id,
          value: ingredient.unit,
        ),
      );
    }

    return ingredient.copyWith(
      schemaVersion: canonicalIngredientMigrationVersion,
      canonicalIngredientId: canonicalIngredientId,
      canonicalUnitId: canonicalUnitId,
      canonicalMappingStatus: mappingStatus,
    );
  }

  CookingHistoryChange _migrateHistoryChange(
    CookingHistoryChange change,
    String historyId,
    List<IngredientMigrationIssue> issues,
  ) {
    final resolution = registry.resolve(
      change.ingredientName,
      preferredId: change.canonicalIngredientId,
    );
    final canonical = resolution.ingredient;
    if (canonical == null) {
      issues.add(
        IngredientMigrationIssue(
          type: resolution.matchType == CanonicalMatchType.ambiguous
              ? IngredientMigrationIssueType.ambiguousIngredient
              : IngredientMigrationIssueType.unknownIngredient,
          recordId: historyId,
          value: change.ingredientName,
          candidateIds: resolution.candidateIds,
        ),
      );
    }
    final unitId =
        unitEngine.resolveUnitId(change.canonicalUnitId) ??
        unitEngine.resolveUnitId(change.unit);
    if (unitId == null) {
      issues.add(
        IngredientMigrationIssue(
          type: IngredientMigrationIssueType.unknownUnit,
          recordId: historyId,
          value: change.unit,
        ),
      );
    }
    return change.copyWith(
      canonicalIngredientId:
          canonical?.id ?? registry.unmappedIdFor(change.ingredientName),
      canonicalUnitId:
          unitId ??
          canonical?.defaultInventoryUnitId ??
          registry.unmappedIdFor('unit:${change.unit}'),
      canonicalMappingStatus: canonical == null
          ? CanonicalMappingStatus.unmapped
          : CanonicalMappingStatus.mapped,
    );
  }
}
