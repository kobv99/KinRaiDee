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

  // D. Full Animal & Seafood Taxonomy expansion: three species names that
  // used to live only as aliases on a generic id now have their own
  // canonical ids (see the 114-item manifest). A record stamped with the
  // generic id whose stored name positively matches the migrated species
  // name moves to the new specific id; anything else stays generic.
  static const Set<String> _whitelegShrimpNames = <String>{'กุ้งขาว'};
  static const Set<String> _bananaShrimpNames = <String>{'กุ้งแชบ๊วย'};
  static const Set<String> _needleSquidNames = <String>{'หมึกกล้วย'};
  static const Set<String> _bigfinReefSquidNames = <String>{'หมึกหอม'};
  static const Set<String> _greenMusselNames = <String>{'หอยแมลงภู่'};
  static const Set<String> _carpetClamNames = <String>{'หอยลาย'};

  // 'ปลาทับทิม' (red tilapia) was a code-seeded alias of tilapia (see
  // pantry_catalog_canonical_definitions.dart) before the manifest gave it
  // its own id, red_tilapia.
  static const Set<String> _redTilapiaNames = <String>{'ปลาทับทิม'};

  // E. Product Acceptance audit: "generic ingredients must not replace
  // specific approved manifest ingredients" — หมูชิ้น/เนื้อไก่ชิ้น/
  // เนื้อวัวชิ้น/เนื้อปู were aliases of their generic parent, but the
  // manifest names each as its own of the 114 specific entries. Each now
  // has its own id (pork_piece/chicken_piece/beef_piece/crab_meat); a
  // record whose stored name positively identifies one of these moves,
  // everything else stays on the generic.
  static const Set<String> _porkPieceNames = <String>{'หมูชิ้น'};
  static const Set<String> _chickenPieceNames = <String>{'เนื้อไก่ชิ้น'};
  static const Set<String> _beefPieceNames = <String>{'เนื้อวัวชิ้น'};
  static const Set<String> _crabMeatNames = <String>{'เนื้อปู'};

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

    // D. Shrimp/squid/shellfish species ownership: see the constant-set
    // comments above for why these three generics each shed two names.
    if (canonicalId == 'shrimp') {
      if (_whitelegShrimpNames.contains(normalizedName)) {
        return 'whiteleg_shrimp';
      }
      if (_bananaShrimpNames.contains(normalizedName)) {
        return 'banana_shrimp';
      }
    }
    if (canonicalId == 'squid') {
      if (_needleSquidNames.contains(normalizedName)) {
        return 'needle_squid';
      }
      if (_bigfinReefSquidNames.contains(normalizedName)) {
        return 'bigfin_reef_squid';
      }
    }
    if (canonicalId == 'shellfish') {
      if (_greenMusselNames.contains(normalizedName)) {
        return 'green_mussel';
      }
      if (_carpetClamNames.contains(normalizedName)) {
        return 'carpet_clam';
      }
    }
    if (canonicalId == 'tilapia' && _redTilapiaNames.contains(normalizedName)) {
      return 'red_tilapia';
    }

    // E. Generic-to-piece/meat promotions — see the constant-set comments
    // above.
    if (canonicalId == 'pork' && _porkPieceNames.contains(normalizedName)) {
      return 'pork_piece';
    }
    if (canonicalId == 'chicken' &&
        _chickenPieceNames.contains(normalizedName)) {
      return 'chicken_piece';
    }
    if (canonicalId == 'beef' && _beefPieceNames.contains(normalizedName)) {
      return 'beef_piece';
    }
    if (canonicalId == 'crab' && _crabMeatNames.contains(normalizedName)) {
      return 'crab_meat';
    }

    return canonicalId;
  }
}
