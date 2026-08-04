import '../../../core/models/ingredient.dart';
import '../domain/models/cooking_history_entry.dart';
import 'canonical_ingredient_migration.dart';

/// A logged, non-blocking flag raised when a semantic rewrite fires on a
/// record whose stored name doesn't match the expected pattern for that
/// rule. The id-based rewrite still proceeds (the id+schemaVersion gate is
/// authoritative), but the mismatch is surfaced for manual review rather
/// than silently absorbed.
class SemanticMigrationAnomaly {
  const SemanticMigrationAnomaly({
    required this.recordId,
    required this.rule,
    required this.detail,
  });

  final String recordId;
  final String rule;
  final String detail;
}

class CanonicalIngredientSemanticMigrationResult {
  const CanonicalIngredientSemanticMigrationResult({
    required this.pantry,
    required this.history,
    required this.anomalies,
    required this.changed,
  });

  final List<Ingredient> pantry;
  final List<CookingHistoryEntry> history;
  final List<SemanticMigrationAnomaly> anomalies;
  final bool changed;
}

/// Corrects canonical-id *meaning* changes introduced by the Animal &
/// Seafood Taxonomy MVP — distinct from [CanonicalIngredientMigration],
/// which only resolves names/units against the registry and never rewrites
/// an id a record already has. Must run before [CanonicalIngredientMigration]
/// during startup: it relies on records still carrying their pre-migration
/// `schemaVersion` to know which ones predate the meaning change; once
/// [CanonicalIngredientMigration] stamps every record with the current
/// version, that signal is gone.
///
/// Every rule below is gated by `schemaVersion < canonicalIngredientMigrationVersion`,
/// which makes re-running this migration idempotent: already-migrated
/// records (or genuinely new records created after this ships) are never
/// touched again.
class CanonicalIngredientSemanticMigration {
  const CanonicalIngredientSemanticMigration();

  static const Set<String> _drumstickNames = <String>{
    'น่องไก่',
    'น่องไก่ทั้งอัน',
  };
  static const Set<String> _thighNames = <String>{
    'สะโพกไก่',
    'เนื้อสะโพกไก่',
    'chicken thigh',
    'chicken thighs',
  };
  static const Set<String> _mincedBeefNames = <String>{'เนื้อบด', 'เนื้อสับ'};
  static const Set<String> _fishFilletNames = <String>{'เนื้อปลาแล่', 'ปลาแล่'};

  CanonicalIngredientSemanticMigrationResult migrate({
    required List<Ingredient> pantry,
    required List<CookingHistoryEntry> history,
  }) {
    final anomalies = <SemanticMigrationAnomaly>[];
    var changed = false;
    final remapByLotId = <String, String>{};

    final migratedPantry = pantry
        .map((ingredient) {
          if (ingredient.schemaVersion >= canonicalIngredientMigrationVersion) {
            return ingredient;
          }
          final remapped = _applyRules(
            canonicalId: ingredient.canonicalIngredientId,
            name: ingredient.name,
            recordId: ingredient.id,
            anomalies: anomalies,
          );
          if (remapped == ingredient.canonicalIngredientId) {
            return ingredient;
          }
          changed = true;
          remapByLotId[ingredient.id] = remapped;
          return ingredient.copyWith(canonicalIngredientId: remapped);
        })
        .toList(growable: false);

    final migratedHistory = history
        .map((entry) {
          if (entry.schemaVersion >= canonicalIngredientMigrationVersion) {
            return entry;
          }
          var entryChanged = false;
          final changes = entry.changes
              .map((change) {
                final byLot = remapByLotId[change.ingredientId];
                final remapped =
                    byLot ??
                    _applyRules(
                      canonicalId: change.canonicalIngredientId,
                      name: change.ingredientName,
                      recordId: '${entry.id}:${change.ingredientId}',
                      anomalies: anomalies,
                    );
                if (remapped == change.canonicalIngredientId) {
                  return change;
                }
                entryChanged = true;
                return change.copyWith(canonicalIngredientId: remapped);
              })
              .toList(growable: false);
          if (!entryChanged) {
            return entry;
          }
          changed = true;
          return entry.copyWith(changes: changes);
        })
        .toList(growable: false);

    return CanonicalIngredientSemanticMigrationResult(
      pantry: List<Ingredient>.unmodifiable(migratedPantry),
      history: List<CookingHistoryEntry>.unmodifiable(migratedHistory),
      anomalies: List<SemanticMigrationAnomaly>.unmodifiable(anomalies),
      changed: changed,
    );
  }

  String _applyRules({
    required String canonicalId,
    required String name,
    required String recordId,
    required List<SemanticMigrationAnomaly> anomalies,
  }) {
    final normalizedName = name.trim().toLowerCase();

    // A. Chicken anatomy: chicken_thigh is repurposed to mean สะโพกไก่ going
    // forward, but the id+version gate alone is NOT sufficient to decide a
    // rewrite — only a name that positively matches a known drumstick
    // pattern is rewritten. A known thigh pattern (or an unrecognized name)
    // is left as chicken_thigh; unrecognized names are additionally logged
    // as an anomaly so they get manual review rather than a silent guess
    // in either direction.
    if (canonicalId == 'chicken_thigh') {
      if (_drumstickNames.contains(normalizedName)) {
        return 'chicken_drumstick';
      }
      if (_thighNames.contains(normalizedName)) {
        return canonicalId;
      }
      anomalies.add(
        SemanticMigrationAnomaly(
          recordId: recordId,
          rule: 'chicken_thigh_ambiguous_name',
          detail:
              'canonicalIngredientId=chicken_thigh with unrecognized stored '
              'name "$name"; kept as chicken_thigh rather than guessing — '
              'please review whether this record actually meant น่องไก่ '
              '(chicken_drumstick).',
        ),
      );
      return canonicalId;
    }

    // B. Beef alias ownership: only records whose stored name specifically
    // indicates minced beef move; "beef" otherwise stays generic.
    if (canonicalId == 'beef' && _mincedBeefNames.contains(normalizedName)) {
      return 'minced_beef';
    }

    // C. Fish form ownership: "เนื้อปลา" (generic fish meat) stays on fish;
    // fillet-specific names move to fish_fillet.
    if (canonicalId == 'fish' && _fishFilletNames.contains(normalizedName)) {
      return 'fish_fillet';
    }

    return canonicalId;
  }
}
