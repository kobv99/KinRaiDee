import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/domain/units/unit_contract.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/application/canonical_ingredient_migration.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26);
  final migration = CanonicalIngredientMigration(
    registry: CanonicalIngredientRegistry(
      ingredients: <CanonicalIngredient>[
        CanonicalIngredient(
          id: 'chicken',
          canonicalName: 'Chicken',
          localizedNames: const <String, String>{'th': 'ไก่'},
          aliases: const <String>[
            'Chicken Breast',
            'Boneless Chicken Breast',
            'อกไก่',
          ],
          searchKeywords: const <String>[],
          category: 'protein',
          defaultStorageType: IngredientStorageType.refrigerated,
          defaultPurchaseUnitId: 'kilogram',
          defaultInventoryUnitId: 'gram',
        ),
      ],
    ),
    unitEngine: UnitConversionEngine.standard(),
  );

  test('migrates Pantry and History without changing user data', () {
    final pantry = <Ingredient>[
      _pantry(
        id: 'lot-1',
        name: 'Chicken Breast',
        unit: 'kg',
        quantity: 1.25,
        now: now,
      ),
    ];
    final history = <CookingHistoryEntry>[
      CookingHistoryEntry(
        id: 'history-1',
        recipeId: 'recipe',
        recipeName: 'Recipe',
        servings: 2,
        changes: const <CookingHistoryChange>[
          CookingHistoryChange(
            ingredientId: 'lot-1',
            ingredientName: 'Chicken Breast',
            unit: 'kg',
            beforeQuantity: 2,
            originalAfterQuantity: 1.25,
            afterQuantity: 1.25,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        status: CookingHistoryStatus.completed,
      ),
    ];

    final result = migration.migrate(pantry: pantry, history: history);

    expect(result.changed, isTrue);
    expect(result.mappedCount, 1);
    expect(result.unmappedCount, 0);
    expect(result.issues, isEmpty);
    expect(result.pantry.single.canonicalIngredientId, 'chicken');
    expect(result.pantry.single.canonicalUnitId, 'kilogram');
    expect(result.pantry.single.name, 'Chicken Breast');
    expect(result.pantry.single.quantity, 1.25);
    expect(
      result.history.single.changes.single.canonicalIngredientId,
      'chicken',
    );
  });

  test('preserves and reports unknown ingredients and units', () {
    final original = _pantry(
      id: 'lot-unknown',
      name: 'Family secret ingredient',
      unit: 'scoop',
      quantity: 4,
      now: now,
    );

    final result = migration.migrate(
      pantry: <Ingredient>[original],
      history: const <CookingHistoryEntry>[],
    );

    final migrated = result.pantry.single;
    expect(migrated.name, original.name);
    expect(migrated.unit, original.unit);
    expect(migrated.quantity, original.quantity);
    expect(migrated.canonicalMappingStatus, CanonicalMappingStatus.unmapped);
    expect(migrated.canonicalIngredientId, startsWith('unmapped_'));
    expect(
      result.issues.map((issue) => issue.type),
      containsAll(<Object>[
        IngredientMigrationIssueType.unknownIngredient,
        IngredientMigrationIssueType.unknownUnit,
      ]),
    );
  });

  test('is idempotent after a successful migration', () {
    final first = migration.migrate(
      pantry: <Ingredient>[
        _pantry(
          id: 'lot-1',
          name: 'อกไก่',
          unit: 'กรัม',
          quantity: 500,
          now: now,
        ),
      ],
      history: const <CookingHistoryEntry>[],
    );
    final second = migration.migrate(
      pantry: first.pantry,
      history: first.history,
    );

    expect(second.changed, isFalse);
    expect(second.pantry.single.toJson(), first.pantry.single.toJson());
  });
}

Ingredient _pantry({
  required String id,
  required String name,
  required String unit,
  required double quantity,
  required DateTime now,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: 'test',
    emoji: 'x',
    quantity: quantity,
    unit: unit,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  );
}
