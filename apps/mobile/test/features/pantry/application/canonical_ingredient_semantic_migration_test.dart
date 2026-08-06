import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/application/canonical_ingredient_migration.dart';
import 'package:mobile/features/pantry/application/canonical_ingredient_semantic_migration.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';

void main() {
  final now = DateTime.utc(2026, 8, 4);
  const migration = CanonicalIngredientSemanticMigration();

  group('A. Chicken anatomy: chicken_thigh -> chicken_drumstick', () {
    test(
      'an old chicken_thigh/น่องไก่ record migrates to chicken_drumstick',
      () {
        final result = migration.migrate(
          pantry: <Ingredient>[
            _pantry(
              id: 'lot-1',
              name: 'น่องไก่',
              canonicalId: 'chicken_thigh',
              schemaVersion: 2,
              now: now,
            ),
          ],
          history: const <CookingHistoryEntry>[],
        );

        expect(result.changed, isTrue);
        expect(result.pantry.single.canonicalIngredientId, 'chicken_drumstick');
        expect(result.anomalies, isEmpty);
      },
    );

    test(
      'an old chicken_thigh/น่องไก่ทั้งอัน record migrates to chicken_drumstick',
      () {
        final result = migration.migrate(
          pantry: <Ingredient>[
            _pantry(
              id: 'lot-1',
              name: 'น่องไก่ทั้งอัน',
              canonicalId: 'chicken_thigh',
              schemaVersion: 2,
              now: now,
            ),
          ],
          history: const <CookingHistoryEntry>[],
        );

        expect(result.pantry.single.canonicalIngredientId, 'chicken_drumstick');
        expect(result.anomalies, isEmpty);
      },
    );

    test('an old chicken_thigh/"Chicken Thigh" (English) record remains '
        'chicken_thigh', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'Chicken Thigh',
            canonicalId: 'chicken_thigh',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'chicken_thigh');
      expect(result.anomalies, isEmpty);
    });

    test('an old chicken_thigh/สะโพกไก่ record remains chicken_thigh', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'สะโพกไก่',
            canonicalId: 'chicken_thigh',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'chicken_thigh');
      expect(result.anomalies, isEmpty);
    });

    test('a version-3 chicken_thigh/สะโพกไก่ record is left unchanged', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'สะโพกไก่',
            canonicalId: 'chicken_thigh',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'chicken_thigh');
    });

    test('an old chicken_thigh record with a suspicious/unrecognized name '
        'remains chicken_thigh and logs an anomaly rather than guessing', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'ไก่ทอด', // unrelated stored name — not a known thigh or
            // drumstick pattern
            canonicalId: 'chicken_thigh',
            schemaVersion: 1,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'chicken_thigh');
      expect(result.anomalies, hasLength(1));
      expect(result.anomalies.single.rule, 'chicken_thigh_ambiguous_name');
      expect(result.anomalies.single.recordId, 'lot-1');
    });
  });

  group('B. Beef alias ownership: beef -> minced_beef', () {
    test('an old beef/เนื้อบด record migrates to minced_beef', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อบด',
            canonicalId: 'beef',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'minced_beef');
    });

    test('an old beef/เนื้อสับ record migrates to minced_beef', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อสับ',
            canonicalId: 'beef',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'minced_beef');
    });

    test('a generic old beef record (not minced) stays on beef', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อวัวสด',
            canonicalId: 'beef',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'beef');
    });
  });

  group('C. Fish form ownership: fish -> fish_fillet', () {
    test('an old fish/เนื้อปลาแล่ record migrates to fish_fillet', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อปลาแล่',
            canonicalId: 'fish',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'fish_fillet');
    });

    test('an old fish/ปลาแล่ record migrates to fish_fillet', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'ปลาแล่',
            canonicalId: 'fish',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'fish_fillet');
    });

    test('an old fish/เนื้อปลา (generic fish meat) record stays on fish', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อปลา',
            canonicalId: 'fish',
            schemaVersion: 2,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'fish');
    });
  });

  group('D. Full Animal & Seafood Taxonomy expansion: species names promoted '
      'from generic aliases to their own canonical ids', () {
    test('an old shrimp/กุ้งขาว record migrates to whiteleg_shrimp', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'กุ้งขาว',
            canonicalId: 'shrimp',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isTrue);
      expect(result.pantry.single.canonicalIngredientId, 'whiteleg_shrimp');
    });

    test('an old shrimp/กุ้งแชบ๊วย record migrates to banana_shrimp', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'กุ้งแชบ๊วย',
            canonicalId: 'shrimp',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'banana_shrimp');
    });

    test('an old shrimp/กุ้งสด (generic) record stays on shrimp', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'กุ้งสด',
            canonicalId: 'shrimp',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'shrimp');
    });

    test('an old squid/หมึกกล้วย record migrates to needle_squid', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หมึกกล้วย',
            canonicalId: 'squid',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'needle_squid');
    });

    test('an old squid/หมึกหอม record migrates to bigfin_reef_squid', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หมึกหอม',
            canonicalId: 'squid',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'bigfin_reef_squid');
    });

    test('an old shellfish/หอยแมลงภู่ record migrates to green_mussel', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หอยแมลงภู่',
            canonicalId: 'shellfish',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'green_mussel');
    });

    test('an old shellfish/หอยลาย record migrates to carpet_clam', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หอยลาย',
            canonicalId: 'shellfish',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'carpet_clam');
    });

    test('an old tilapia/ปลาทับทิม record migrates to red_tilapia (the '
        'code-seeded alias in pantry_catalog_canonical_definitions.dart '
        'was removed in favor of its own manifest id)', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'ปลาทับทิม',
            canonicalId: 'tilapia',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'red_tilapia');
    });

    test('an old tilapia/ปลานิลสด (generic) record stays on tilapia', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'ปลานิลสด',
            canonicalId: 'tilapia',
            schemaVersion: 3,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'tilapia');
    });

    test('a record already stamped at the current migration version is '
        'never re-touched, even if its name matches a migrated pattern', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'กุ้งขาว',
            canonicalId: 'shrimp',
            schemaVersion: canonicalIngredientMigrationVersion,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'shrimp');
    });
  });

  group('E. Product Acceptance audit: generic-to-piece/meat promotions', () {
    test('an old pork/หมูชิ้น record migrates to pork_piece', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หมูชิ้น',
            canonicalId: 'pork',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isTrue);
      expect(result.pantry.single.canonicalIngredientId, 'pork_piece');
    });

    test('an old pork/หมูสด (genuinely generic) record stays on pork', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หมูสด',
            canonicalId: 'pork',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'pork');
    });

    test('an old chicken/เนื้อไก่ชิ้น record migrates to chicken_piece', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อไก่ชิ้น',
            canonicalId: 'chicken',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'chicken_piece');
    });

    test(
      'an old chicken/ไก่สด (genuinely generic) record stays on chicken',
      () {
        final result = migration.migrate(
          pantry: <Ingredient>[
            _pantry(
              id: 'lot-1',
              name: 'ไก่สด',
              canonicalId: 'chicken',
              schemaVersion: 4,
              now: now,
            ),
          ],
          history: const <CookingHistoryEntry>[],
        );

        expect(result.changed, isFalse);
        expect(result.pantry.single.canonicalIngredientId, 'chicken');
      },
    );

    test('an old beef/เนื้อวัวชิ้น record migrates to beef_piece', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อวัวชิ้น',
            canonicalId: 'beef',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'beef_piece');
    });

    test('an old beef/เนื้อวัวสด (genuinely generic) record stays on beef', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อวัวสด',
            canonicalId: 'beef',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'beef');
    });

    test('an old crab/เนื้อปู record migrates to crab_meat', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'เนื้อปู',
            canonicalId: 'crab',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.pantry.single.canonicalIngredientId, 'crab_meat');
    });

    test('an old crab/crab (English generic) record stays on crab', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'crab',
            canonicalId: 'crab',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'crab');
    });

    test('cooking history changes for these promotions are corrected '
        'consistently with their originating lot', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หมูชิ้น',
            canonicalId: 'pork',
            schemaVersion: 4,
            now: now,
          ),
        ],
        history: <CookingHistoryEntry>[
          _history(
            id: 'history-1',
            ingredientId: 'lot-1',
            ingredientName: 'หมูชิ้น',
            canonicalId: 'pork',
            schemaVersion: 4,
            now: now,
          ),
        ],
      );

      expect(result.pantry.single.canonicalIngredientId, 'pork_piece');
      expect(
        result.history.single.changes.single.canonicalIngredientId,
        'pork_piece',
      );
    });

    test('a history entry with no matching pantry lot is corrected '
        'independently, by its own stored name', () {
      final result = migration.migrate(
        pantry: const <Ingredient>[],
        history: <CookingHistoryEntry>[
          _history(
            id: 'history-1',
            ingredientId: 'missing-lot',
            ingredientName: 'เนื้อปู',
            canonicalId: 'crab',
            schemaVersion: 4,
            now: now,
          ),
        ],
      );

      expect(
        result.history.single.changes.single.canonicalIngredientId,
        'crab_meat',
      );
    });

    test('a record already stamped at the current migration version is '
        'never re-touched, even for these promotions', () {
      final result = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'หมูชิ้น',
            canonicalId: 'pork',
            schemaVersion: canonicalIngredientMigrationVersion,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );

      expect(result.changed, isFalse);
      expect(result.pantry.single.canonicalIngredientId, 'pork');
    });
  });

  test('unrelated pantry records are unaffected', () {
    final result = migration.migrate(
      pantry: <Ingredient>[
        _pantry(
          id: 'lot-1',
          name: 'หมูสามชั้น',
          canonicalId: 'pork_belly',
          schemaVersion: 2,
          now: now,
        ),
      ],
      history: const <CookingHistoryEntry>[],
    );

    expect(result.changed, isFalse);
    expect(result.pantry.single.canonicalIngredientId, 'pork_belly');
  });

  test('cooking history changes are corrected consistently with their lot', () {
    final result = migration.migrate(
      pantry: <Ingredient>[
        _pantry(
          id: 'lot-1',
          name: 'น่องไก่',
          canonicalId: 'chicken_thigh',
          schemaVersion: 2,
          now: now,
        ),
      ],
      history: <CookingHistoryEntry>[
        CookingHistoryEntry(
          schemaVersion: 2,
          id: 'history-1',
          recipeId: 'recipe',
          recipeName: 'Recipe',
          servings: 2,
          changes: const <CookingHistoryChange>[
            CookingHistoryChange(
              ingredientId: 'lot-1',
              ingredientName: 'น่องไก่',
              unit: 'กรัม',
              beforeQuantity: 500,
              originalAfterQuantity: 300,
              afterQuantity: 300,
              canonicalIngredientId: 'chicken_thigh',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          status: CookingHistoryStatus.completed,
        ),
      ],
    );

    expect(result.changed, isTrue);
    expect(
      result.history.single.changes.single.canonicalIngredientId,
      'chicken_drumstick',
    );
  });

  test('cooking history follows a stay-put decision consistently with its lot '
      '(not just a rewrite decision)', () {
    final result = migration.migrate(
      pantry: <Ingredient>[
        _pantry(
          id: 'lot-1',
          name: 'สะโพกไก่',
          canonicalId: 'chicken_thigh',
          schemaVersion: 2,
          now: now,
        ),
      ],
      history: <CookingHistoryEntry>[
        CookingHistoryEntry(
          schemaVersion: 2,
          id: 'history-1',
          recipeId: 'recipe',
          recipeName: 'Recipe',
          servings: 2,
          changes: const <CookingHistoryChange>[
            CookingHistoryChange(
              ingredientId: 'lot-1',
              ingredientName: 'สะโพกไก่',
              unit: 'กรัม',
              beforeQuantity: 500,
              originalAfterQuantity: 300,
              afterQuantity: 300,
              canonicalIngredientId: 'chicken_thigh',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          status: CookingHistoryStatus.completed,
        ),
      ],
    );

    expect(result.changed, isFalse);
    expect(result.pantry.single.canonicalIngredientId, 'chicken_thigh');
    expect(
      result.history.single.changes.single.canonicalIngredientId,
      'chicken_thigh',
    );
    expect(result.anomalies, isEmpty);
  });

  test('a history change referencing an already-deleted pantry lot is still '
      'corrected directly by its own stored id/name', () {
    final result = migration.migrate(
      pantry: const <Ingredient>[],
      history: <CookingHistoryEntry>[
        CookingHistoryEntry(
          schemaVersion: 2,
          id: 'history-1',
          recipeId: 'recipe',
          recipeName: 'Recipe',
          servings: 2,
          changes: const <CookingHistoryChange>[
            CookingHistoryChange(
              ingredientId: 'deleted-lot',
              ingredientName: 'น่องไก่',
              unit: 'กรัม',
              beforeQuantity: 500,
              originalAfterQuantity: 300,
              afterQuantity: 300,
              canonicalIngredientId: 'chicken_thigh',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          status: CookingHistoryStatus.completed,
        ),
      ],
    );

    expect(
      result.history.single.changes.single.canonicalIngredientId,
      'chicken_drumstick',
    );
  });

  test(
    'is idempotent: re-running on already-migrated data changes nothing',
    () {
      final first = migration.migrate(
        pantry: <Ingredient>[
          _pantry(
            id: 'lot-1',
            name: 'น่องไก่',
            canonicalId: 'chicken_thigh',
            schemaVersion: 1,
            now: now,
          ),
        ],
        history: const <CookingHistoryEntry>[],
      );
      expect(first.changed, isTrue);

      // The general CanonicalIngredientMigration stamps schemaVersion to the
      // current version after the semantic pass, which is what makes the
      // gate skip already-migrated records on the next boot.
      final stamped = first.pantry
          .map(
            (ingredient) => ingredient.copyWith(
              schemaVersion: canonicalIngredientMigrationVersion,
            ),
          )
          .toList(growable: false);

      final second = migration.migrate(pantry: stamped, history: first.history);

      expect(second.changed, isFalse);
      expect(second.pantry.single.canonicalIngredientId, 'chicken_drumstick');
      expect(second.anomalies, isEmpty);
    },
  );
}

Ingredient _pantry({
  required String id,
  required String name,
  required String canonicalId,
  required int schemaVersion,
  required DateTime now,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: 'protein',
    emoji: '',
    quantity: 1,
    unit: 'กรัม',
    createdAt: now,
    updatedAt: now,
    schemaVersion: schemaVersion,
    canonicalIngredientId: canonicalId,
    canonicalUnitId: 'gram',
    canonicalMappingStatus: CanonicalMappingStatus.mapped,
  );
}

CookingHistoryEntry _history({
  required String id,
  required String ingredientId,
  required String ingredientName,
  required String canonicalId,
  required int schemaVersion,
  required DateTime now,
}) {
  return CookingHistoryEntry(
    schemaVersion: schemaVersion,
    id: id,
    recipeId: 'recipe',
    recipeName: 'Recipe',
    servings: 2,
    changes: <CookingHistoryChange>[
      CookingHistoryChange(
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        unit: 'กรัม',
        beforeQuantity: 500,
        originalAfterQuantity: 300,
        afterQuantity: 300,
        canonicalIngredientId: canonicalId,
      ),
    ],
    createdAt: now,
    updatedAt: now,
    status: CookingHistoryStatus.completed,
  );
}
