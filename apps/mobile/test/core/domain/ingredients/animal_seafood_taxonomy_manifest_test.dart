import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_search_service.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

/// Structural + content proof for the full Animal & Seafood Taxonomy
/// expansion, run against the real bundled registry. [_manifest] is a
/// verbatim transcription of every numbered line in the authoritative
/// `KinRaiDee_Animal_Seafood_Manifest_114.txt` (114 lines across 11
/// categories) — no name here was invented; each entry is either the
/// manifest's single name, or (for the four "X / Y" lines) both
/// alternatives the manifest itself gave for that one numbered ingredient.
///
/// [_buildMapping] is the explicit manifest-row -> canonical-id mapping the
/// Product Acceptance audit required: it proves the *one-to-one*
/// relationship (114 approved names -> 114 distinct ids), not just that
/// every name is findable somewhere in the registry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CanonicalIngredientRegistry registry;
  late UnitConversionEngine unitEngine;
  late List<_ManifestMatch> mapping;

  setUpAll(() async {
    unitEngine = UnitConversionEngine.standard();
    registry = await IngredientCatalog(
      unitConversionEngine: unitEngine,
    ).loadRegistry();
    mapping = _buildMapping(registry);
  });

  const rootFamilyIds = <String>{
    'pork_family',
    'chicken_family',
    'beef_family',
    'fish_family',
    'shrimp_family',
    'crab_family',
    'squid_family',
    'shellfish_family',
    'other_seafood_family',
  };

  test('exactly 9 root taxonomy families exist', () {
    final roots = registry.ingredients.where(
      (i) =>
          i.nodeType == CanonicalIngredientNodeType.family &&
          i.parentId == null,
    );
    expect(roots.map((i) => i.id).toSet(), rootFamilyIds);
  });

  group(
    'explicit manifest-name -> canonical-id mapping (one-to-one proof)',
    () {
      test('the manifest transcription itself contains exactly 114 rows', () {
        final total = _manifest.values.fold<int>(0, (sum, v) => sum + v.length);
        expect(total, 114);
        expect(mapping, hasLength(114));
      });

      test('every one of the 114 rows maps to exactly one canonical id', () {
        final unmatched = mapping.where((r) => r.id == null).toList();
        expect(
          unmatched,
          isEmpty,
          reason:
              'rows with no canonical id match: '
              '${unmatched.map((r) => '${r.category}/${r.manifestLine}')}',
        );
      });

      test('the set of mapped canonical ids has length exactly 114 (no two '
          'manifest rows map to the same id — aliases and slash-alternatives '
          'collapse to one id each, they never inflate the count)', () {
        final ids = mapping.map((r) => r.id).whereType<String>().toSet();
        expect(ids, hasLength(114));
      });

      test('no two manifest rows map to the same canonical id', () {
        final counts = <String, List<String>>{};
        for (final row in mapping) {
          if (row.id == null) continue;
          counts.putIfAbsent(row.id!, () => <String>[]).add(row.manifestLine);
        }
        final duplicated = <String, List<String>>{
          for (final entry in counts.entries)
            if (entry.value.length > 1) entry.key: entry.value,
        };
        expect(duplicated, isEmpty);
      });

      test(
        'none of the 114 mapped ids has taxonomyType=generic — generic '
        'ingredients must not replace specific approved manifest entries',
        () {
          final genericHits = mapping
              .where((r) => r.taxonomyType == IngredientTaxonomyType.generic)
              .toList();
          expect(
            genericHits,
            isEmpty,
            reason:
                'manifest rows resolved to a generic id: '
                '${genericHits.map((r) => '${r.manifestLine} -> ${r.id}')}',
          );
        },
      );

      test('generic root ingredients (pork/chicken/beef/crab/fish/shrimp/squid/'
          'shellfish) remain valid but stay OUTSIDE the 114 mapped ids', () {
        const generics = <String>{
          'pork',
          'chicken',
          'beef',
          'crab',
          'fish',
          'shrimp',
          'squid',
          'shellfish',
        };
        final mappedIds = mapping.map((r) => r.id).toSet();
        for (final id in generics) {
          final ingredient = registry.byId(id);
          expect(ingredient, isNotNull, reason: '$id must still exist');
          expect(ingredient!.taxonomyType, IngredientTaxonomyType.generic);
          expect(
            mappedIds.contains(id),
            isFalse,
            reason: '$id must not count toward the 114 manifest entries',
          );
        }
      });

      test('family nodes remain outside the 114 count', () {
        final mappedIds = mapping.map((r) => r.id).toSet();
        for (final id in rootFamilyIds) {
          expect(mappedIds.contains(id), isFalse);
        }
      });

      test('known non-manifest extras (moo_yor, imitation_crab) remain in the '
          'registry but outside the 114 mapped ids', () {
        final mappedIds = mapping.map((r) => r.id).toSet();
        for (final id in <String>['moo_yor', 'imitation_crab']) {
          expect(registry.byId(id), isNotNull);
          expect(mappedIds.contains(id), isFalse);
        }
      });
    },
  );

  test('exact per-category coverage counts match the manifest', () {
    const expectedCounts = <String, int>{
      'หมู': 18,
      'ไก่': 14,
      'เนื้อวัว': 19,
      'ปลาน้ำจืด': 10,
      'ปลาทะเล': 10,
      'ส่วนของปลา': 6,
      'กุ้ง': 8,
      'ปู': 7,
      'ปลาหมึก': 7,
      'หอย': 9,
      'สัตว์ทะเลอื่น ๆ': 6,
    };
    for (final entry in expectedCounts.entries) {
      expect(
        _manifest[entry.key]!.length,
        entry.value,
        reason: '${entry.key} manifest transcription length mismatch',
      );
      final actual = mapping.where((r) => r.category == entry.key).length;
      expect(
        actual,
        entry.value,
        reason: '${entry.key} mapped-row count mismatch',
      );
    }
  });

  test('other_seafood_family has exactly its 6 approved children', () {
    final members = registry.ingredients.where(
      (i) => i.parentId == 'other_seafood_family',
    );
    expect(members.map((i) => i.id).toSet(), <String>{
      'mantis_shrimp',
      'krill',
      'jellyfish',
      'sea_cucumber',
      'sea_urchin',
      'horseshoe_crab_roe',
    });
    for (final member in members) {
      expect(member.nodeType, CanonicalIngredientNodeType.ingredient);
      expect(member.canSelectAsMainIngredient, isTrue);
    }
  });

  test('the four known generic substitutions are now their own distinct ids, '
      'not aliases of the generic', () {
    const promotions = <String, String>{
      'pork_piece': 'หมูชิ้น',
      'chicken_piece': 'เนื้อไก่ชิ้น',
      'beef_piece': 'เนื้อวัวชิ้น',
      'crab_meat': 'เนื้อปู',
    };
    for (final entry in promotions.entries) {
      final ingredient = registry.byId(entry.key);
      expect(ingredient, isNotNull, reason: '${entry.key} must exist');
      expect(ingredient!.displayName(), entry.value);
      expect(ingredient.taxonomyType, isNot(IngredientTaxonomyType.generic));
      expect(ingredient.canSelectAsMainIngredient, isTrue);
    }
    // The old generic aliases must be gone.
    expect(registry.byId('pork')!.aliases, isNot(contains('หมูชิ้น')));
    expect(registry.byId('chicken')!.aliases, isNot(contains('เนื้อไก่ชิ้น')));
    expect(registry.byId('beef')!.aliases, isNot(contains('เนื้อวัวชิ้น')));
    expect(registry.byId('crab')!.aliases, isNot(contains('เนื้อปู')));
  });

  test('display-name-vs-alias audit: exactly the two known cases match only '
      'through an alias, not the localized display name — reported for '
      'Product decision, not silently accepted and not auto-renamed', () {
    final aliasMatches = mapping.where((r) => r.source == 'alias').toList();
    final described = aliasMatches
        .map(
          (r) =>
              '${r.manifestLine} -> ${r.id} (displayName: '
              '${r.displayName})',
        )
        .toSet();
    expect(described, <String>{
      'สามชั้น -> pork_belly (displayName: หมูสามชั้น)',
      'ไก่บด -> minced_chicken (displayName: ไก่สับ)',
    });
  });

  test('กั้ง (mantis_shrimp) and กุ้ง (shrimp) resolve deterministically to '
      'their own distinct ids — regression coverage for the '
      'normalizeIngredientKey mark-stripping collision found and fixed by '
      'this manifest expansion', () {
    expect(registry.resolve('กั้ง').ingredient?.id, 'mantis_shrimp');
    expect(registry.resolve('กุ้ง').ingredient?.id, 'shrimp');
  });

  test('the chicken_thigh/chicken_drumstick correction remains in effect', () {
    final thigh = registry.byId('chicken_thigh');
    final drumstick = registry.byId('chicken_drumstick');
    expect(thigh, isNotNull);
    expect(drumstick, isNotNull);
    expect(thigh!.displayName(), 'สะโพกไก่');
    expect(drumstick!.displayName(), 'น่องไก่');
    expect(thigh.id, isNot(drumstick.id));
  });

  group('registry-wide identity hygiene', () {
    test('no duplicate canonical ids (construction already proves this — '
        'the registry constructor throws on a duplicate id)', () {
      expect(registry.ingredients, isNotEmpty);
    });

    test('no duplicate alias/name ownership: no exact identity string '
        '(canonicalName/localizedName/alias — deliberately excluding '
        'searchKeywords/tags, which are shared, non-identity category '
        'labels like "เนื้อสัตว์"/"อาหารทะเล" by design) is registered by two '
        'different ids', () {
      final owners = _identityOwners(registry, normalized: false);
      final ambiguous = <String, Set<String>>{
        for (final entry in owners.entries)
          if (entry.value.length > 1) entry.key: entry.value,
      };
      expect(ambiguous, isEmpty);
    });

    test('no duplicate *normalized*-key identity ownership either — this is '
        'the stronger check that actually matches registry.resolve()\'s own '
        'lookup semantics. กั้ง (mantis_shrimp) and กุ้ง (shrimp) originally '
        'collided here: normalizeIngredientKey stripped Thai combining '
        'vowel/tone marks entirely, collapsing both distinct words to the '
        'same key. Fixed by keeping \\p{M} (marks) in the normalized key — '
        'strictly additive, so no previously-matching query/name pair can '
        'stop matching', () {
      final owners = _identityOwners(registry, normalized: true);
      final ambiguous = <String, Set<String>>{
        for (final entry in owners.entries)
          if (entry.value.length > 1) entry.key: entry.value,
      };
      expect(ambiguous, isEmpty);
    });

    test('no orphan parentId anywhere in the registry', () {
      for (final ingredient in registry.ingredients) {
        final parentId = ingredient.parentId;
        if (parentId == null) {
          continue;
        }
        expect(
          registry.byId(parentId),
          isNotNull,
          reason: '${ingredient.id} references missing parent $parentId',
        );
      }
    });

    test('no taxonomy cycles (construction already proves this — the '
        'registry constructor throws on a circular parent chain)', () {
      for (final root in rootFamilyIds) {
        expect(() => registry.ancestorChainFor(root), returnsNormally);
      }
    });

    test('family nodes carry nodeType=family, taxonomyType=null, '
        'selectableAsMainIngredient=false', () {
      for (final id in rootFamilyIds) {
        final family = registry.byId(id)!;
        expect(family.nodeType, CanonicalIngredientNodeType.family);
        expect(family.taxonomyType, isNull);
        expect(family.selectableAsMainIngredient, isFalse);
        expect(family.canSelectAsMainIngredient, isFalse);
      }
    });

    test('every mapped manifest id is reachable from exactly one taxonomy '
        'root', () {
      for (final row in mapping) {
        final id = row.id;
        if (id == null) continue;
        final ancestors = registry.ancestorIdsFor(id);
        final matchingRoots = rootFamilyIds.intersection(ancestors);
        expect(
          matchingRoots.length,
          1,
          reason: '$id (${row.manifestLine}) ancestors=$matchingRoots',
        );
      }
    });

    test('every selectable ingredient under the 9 roots is reachable from '
        'exactly one taxonomy root', () {
      for (final ingredient in registry.ingredients) {
        if (ingredient.nodeType != CanonicalIngredientNodeType.ingredient) {
          continue;
        }
        final ancestors = registry.ancestorIdsFor(ingredient.id);
        final matchingRoots = rootFamilyIds.intersection(ancestors);
        // Zero is valid (ingredient outside the animal/seafood taxonomy,
        // e.g. a vegetable); the invariant under test is never *more*
        // than one root claiming the same descendant.
        expect(
          matchingRoots.length,
          lessThanOrEqualTo(1),
          reason:
              '${ingredient.id} is reachable from multiple roots: '
              '$matchingRoots',
        );
      }
    });
  });

  group('unit and quantity validity for every mapped manifest ingredient', () {
    test('all defaultPantryQuantity values are finite and > 0', () {
      for (final row in mapping) {
        final ingredient = row.id == null ? null : registry.byId(row.id!);
        final quantity = ingredient?.defaultPantryQuantity;
        if (quantity == null) {
          continue;
        }
        expect(
          quantity.isFinite && quantity > 0,
          isTrue,
          reason: '${row.id} has invalid defaultPantryQuantity $quantity',
        );
      }
    });

    test('every mapped ingredient default/purchase/recommended unit '
        'resolves against UnitConversionEngine', () {
      for (final row in mapping) {
        final ingredient = row.id == null ? null : registry.byId(row.id!);
        if (ingredient == null) continue;
        expect(
          unitEngine.resolveUnit(ingredient.defaultInventoryUnitId),
          isNotNull,
          reason: '${ingredient.id}.defaultInventoryUnitId does not resolve',
        );
        expect(
          unitEngine.resolveUnit(ingredient.defaultPurchaseUnitId),
          isNotNull,
          reason: '${ingredient.id}.defaultPurchaseUnitId does not resolve',
        );
        expect(
          unitEngine.resolveUnit(ingredient.preferredUnitId),
          isNotNull,
          reason: '${ingredient.id}.preferredUnitId does not resolve',
        );
        for (final unitId in ingredient.recommendedUnitIds) {
          expect(
            unitEngine.resolveUnit(unitId),
            isNotNull,
            reason: '${ingredient.id} recommends unresolvable unit $unitId',
          );
        }
      }
    });
  });

  group('search substring matching over the expanded registry', () {
    test('every manifest name is a substring match against its own '
        'ingredient — proves "all localized names are searchable"', () {
      for (final category in _manifest.entries) {
        for (final line in category.value) {
          for (final name in line.split(' / ').map((s) => s.trim())) {
            final needle = normalizeIngredientKey(name);
            final hasOwner = registry.ingredients.any(
              (i) =>
                  i.nodeType == CanonicalIngredientNodeType.ingredient &&
                  i.searchableNames.any(
                    (n) => normalizeIngredientKey(n).contains(needle),
                  ),
            );
            expect(
              hasOwner,
              isTrue,
              reason: '"$name" (${category.key}) is not searchable',
            );
          }
        }
      }
    });
  });

  group('shrimp/squid/shellfish alias migration', () {
    test('the generic ids no longer own the migrated species names as '
        'aliases', () {
      final shrimp = registry.byId('shrimp')!;
      expect(shrimp.aliases, isNot(contains('กุ้งขาว')));
      expect(shrimp.aliases, isNot(contains('กุ้งแชบ๊วย')));

      final squid = registry.byId('squid')!;
      expect(squid.aliases, isNot(contains('หมึกกล้วย')));
      expect(squid.aliases, isNot(contains('หมึกหอม')));

      final shellfish = registry.byId('shellfish')!;
      expect(shellfish.aliases, isNot(contains('หอยแมลงภู่')));
      expect(shellfish.aliases, isNot(contains('หอยลาย')));
    });

    test('the migrated names now resolve to their own specific ids, not '
        'the generic parent', () {
      expect(registry.resolve('กุ้งขาว').ingredient?.id, 'whiteleg_shrimp');
      expect(registry.resolve('กุ้งแชบ๊วย').ingredient?.id, 'banana_shrimp');
      expect(registry.resolve('หมึกกล้วย').ingredient?.id, 'needle_squid');
      expect(registry.resolve('หมึกหอม').ingredient?.id, 'bigfin_reef_squid');
      expect(registry.resolve('หอยแมลงภู่').ingredient?.id, 'green_mussel');
      expect(registry.resolve('หอยลาย').ingredient?.id, 'carpet_clam');
    });
  });

  group('normalizeIngredientKey regression audit', () {
    test('exact resolution for the five audited names', () {
      const expected = <String, String>{
        'กั้ง': 'mantis_shrimp',
        'กุ้ง': 'shrimp',
        'ปลาทับทิม': 'red_tilapia',
        'หมึกกล้วย': 'needle_squid',
        'หอยลาย': 'carpet_clam',
      };
      for (final entry in expected.entries) {
        expect(
          registry.resolve(entry.key).ingredient?.id,
          entry.value,
          reason: 'resolve(${entry.key})',
        );
      }
    });

    test('canonical (substring) search returns the required ids for the '
        'five audited queries', () {
      const service = CanonicalIngredientSearchService();
      List<String> idsFor(String query) => service
          .search(registry, query)
          .map((r) => r.ingredient.id)
          .toList(growable: false);

      expect(
        idsFor('น่อง'),
        containsAll(<String>['chicken_drumstick', 'beef_shank']),
      );
      expect(idsFor('กั้ง'), containsAll(<String>['mantis_shrimp']));
      expect(idsFor('กุ้ง'), containsAll(<String>['shrimp']));
      expect(idsFor('ปลาทับทิม'), containsAll(<String>['red_tilapia']));
      expect(idsFor('เนื้อปู'), containsAll(<String>['crab_meat']));
    });

    test('mark-omitted queries (tone/vowel mark dropped from an audited name) '
        '— observational only, no new requirement invented. Documents actual '
        'behavior: these narrow queries return fewer/no results after the '
        'fix, because the fix makes matching *more* mark-sensitive (by '
        'design, to stop กั้ง/กุ้ง colliding) — no previously-required '
        'example query is affected', () {
      const service = CanonicalIngredientSearchService();
      List<String> idsFor(String query) => service
          .search(registry, query)
          .map((r) => r.ingredient.id)
          .toList(growable: false);

      // 'กัง' omits the ้ tone mark from กั้ง (mantis_shrimp) — no match.
      expect(idsFor('กัง'), isEmpty);
      expect(registry.resolve('กัง').isResolved, isFalse);

      // 'กุง' omits the ้ tone mark from กุ้ง (shrimp) — no match.
      expect(idsFor('กุง'), isEmpty);
      expect(registry.resolve('กุง').isResolved, isFalse);

      // 'นอง' omits the ่ tone mark from น่อง — already didn't match
      // before this fix either (the mark sits between two letters, so
      // even the old space-collapsing normalization broke contiguity);
      // unaffected, included for completeness.
      expect(idsFor('นอง'), isEmpty);
    });
  });
}

/// One row of the explicit manifest -> canonical-id mapping.
class _ManifestMatch {
  const _ManifestMatch({
    required this.category,
    required this.manifestLine,
    required this.id,
    required this.displayName,
    required this.taxonomyType,
    required this.parentId,
    required this.matchedTerm,
    required this.source,
  });

  final String category;
  final String manifestLine;
  final String? id;
  final String? displayName;
  final IngredientTaxonomyType? taxonomyType;
  final String? parentId;
  final String? matchedTerm;

  /// 'name' (canonicalName/localizedName) or 'alias'.
  final String? source;
}

/// Builds the explicit manifest-row -> canonical-id mapping the audit
/// requires. For each manifest line (splitting "X / Y" into its two
/// accepted terms), searches display names first, then aliases — matching
/// [CanonicalIngredientSearchService]'s own precedence-free existence
/// check, but recording *which* field actually matched so alias-only
/// coverage is visible rather than silently accepted.
List<_ManifestMatch> _buildMapping(CanonicalIngredientRegistry registry) {
  final selectable = registry.ingredients
      .where((i) => i.nodeType == CanonicalIngredientNodeType.ingredient)
      .toList(growable: false);

  final rows = <_ManifestMatch>[];
  for (final category in _manifest.entries) {
    for (final line in category.value) {
      final terms = line.split(' / ').map((s) => s.trim()).toList();
      CanonicalIngredient? matched;
      String? matchedTerm;
      String? source;

      outer:
      for (final term in terms) {
        for (final ingredient in selectable) {
          final displayNames = <String>{
            ingredient.canonicalName,
            ...ingredient.localizedNames.values,
          };
          if (displayNames.contains(term)) {
            matched = ingredient;
            matchedTerm = term;
            source = 'name';
            break outer;
          }
        }
      }
      if (matched == null) {
        outer:
        for (final term in terms) {
          for (final ingredient in selectable) {
            if (ingredient.aliases.contains(term)) {
              matched = ingredient;
              matchedTerm = term;
              source = 'alias';
              break outer;
            }
          }
        }
      }

      rows.add(
        _ManifestMatch(
          category: category.key,
          manifestLine: line,
          id: matched?.id,
          displayName: matched?.displayName(),
          taxonomyType: matched?.taxonomyType,
          parentId: matched?.parentId,
          matchedTerm: matchedTerm,
          source: source,
        ),
      );
    }
  }
  return rows;
}

/// Maps each identity string (canonicalName/localizedName/alias — never
/// searchKeywords/tags, which are intentionally shared category labels)
/// to the set of ingredient ids that register it, either as the raw exact
/// string or — with [normalized] — through the same normalizeIngredientKey
/// transform `resolve()` itself uses to index and look up names.
Map<String, Set<String>> _identityOwners(
  CanonicalIngredientRegistry registry, {
  required bool normalized,
}) {
  final owners = <String, Set<String>>{};
  for (final ingredient in registry.ingredients) {
    if (ingredient.nodeType != CanonicalIngredientNodeType.ingredient) {
      continue;
    }
    final identityNames = <String>{
      ingredient.canonicalName,
      ...ingredient.localizedNames.values,
      ...ingredient.aliases,
    };
    for (final name in identityNames) {
      final key = normalized ? normalizeIngredientKey(name) : name;
      if (key.isEmpty) {
        continue;
      }
      owners.putIfAbsent(key, () => <String>{}).add(ingredient.id);
    }
  }
  return owners;
}

/// Verbatim transcription of every numbered line in
/// `KinRaiDee_Animal_Seafood_Manifest_114.txt`. "X / Y" entries are kept
/// exactly as the manifest wrote them — one numbered line, two accepted
/// Thai names for that single canonical ingredient.
const Map<String, List<String>> _manifest = <String, List<String>>{
  'หมู': <String>[
    'หมูสับ',
    'หมูชิ้น',
    'สันในหมู',
    'สันนอกหมู',
    'สันคอหมู',
    'สามชั้น',
    'ซี่โครงหมู',
    'กระดูกอ่อนหมู',
    'ขาหมู',
    'หนังหมู',
    'ตับหมู',
    'ไส้หมู',
    'กระเพาะหมู',
    'หัวใจหมู',
    'ลิ้นหมู',
    'หูหมู',
    'เลือดหมู',
    'มันหมู',
  ],
  'ไก่': <String>[
    'ไก่ทั้งตัว',
    'เนื้อไก่ชิ้น',
    'อกไก่',
    'สันในไก่',
    'สะโพกไก่',
    'น่องไก่',
    'ปีกไก่',
    'ขาไก่ / ตีนไก่',
    'โครงไก่',
    'หนังไก่',
    'ตับไก่',
    'กึ๋นไก่',
    'หัวใจไก่',
    'ไก่บด',
  ],
  'เนื้อวัว': <String>[
    'เนื้อวัวชิ้น',
    'เนื้อบด / เนื้อสับ',
    'สันในวัว',
    'สันนอกวัว',
    'ริบอาย',
    'ทีโบน',
    'เนื้อเสือร้องไห้',
    'เนื้อสะโพก',
    'เนื้อน่องลาย',
    'เนื้อหน้าอก',
    'ซี่โครงวัว',
    'หางวัว',
    'ลิ้นวัว',
    'ตับวัว',
    'ไส้วัว',
    'ผ้าขี้ริ้ว',
    'เอ็นวัว',
    'ม้ามวัว',
    'กระดูกวัว',
  ],
  'ปลาน้ำจืด': <String>[
    'ปลานิล',
    'ปลาทับทิม',
    'ปลาช่อน',
    'ปลาดุก',
    'ปลาตะเพียน',
    'ปลาคัง',
    'ปลาบึก',
    'ปลาเนื้ออ่อน',
    'ปลากราย',
    'ปลาไหล',
  ],
  'ปลาทะเล': <String>[
    'ปลากะพง',
    'ปลาเก๋า',
    'ปลาทู',
    'ปลาอินทรี',
    'ปลาสำลี',
    'ปลาจะละเม็ด',
    'ปลาแซลมอน',
    'ปลาทูน่า',
    'ปลาซาบะ',
    'ปลาดาบ / ปลากระโทง',
  ],
  'ส่วนของปลา': <String>[
    'เนื้อปลาแล่',
    'หัวปลา',
    'ท้องปลา',
    'ไข่ปลา',
    'หนังปลา',
    'ก้างและกระดูกปลา',
  ],
  'กุ้ง': <String>[
    'กุ้งขาว',
    'กุ้งก้ามกราม',
    'กุ้งแชบ๊วย',
    'กุ้งลายเสือ',
    'กุ้งมังกร',
    'เนื้อกุ้งแกะ',
    'หัวกุ้ง',
    'เปลือกกุ้ง',
  ],
  'ปู': <String>[
    'ปูทะเล',
    'ปูม้า',
    'ปูไข่',
    'ปูนิ่ม',
    'เนื้อปู',
    'กรรเชียงปู',
    'มันปู',
  ],
  'ปลาหมึก': <String>[
    'หมึกกล้วย',
    'หมึกหอม',
    'หมึกกระดอง',
    'หมึกสาย',
    'หนวดหมึก',
    'ไข่หมึก',
    'หมึกแห้ง',
  ],
  'หอย': <String>[
    'หอยแมลงภู่',
    'หอยนางรม',
    'หอยแครง',
    'หอยลาย',
    'หอยหวาน',
    'หอยเชลล์',
    'หอยเป๋าฮื้อ',
    'หอยหลอด',
    'หอยโข่ง / หอยขม',
  ],
  'สัตว์ทะเลอื่น ๆ': <String>[
    'กั้ง',
    'กุ้งเคย',
    'แมงกะพรุน',
    'ปลิงทะเล',
    'เม่นทะเล',
    'ไข่แมงดาทะเล',
  ],
};
