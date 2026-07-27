import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_coordinator.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';
import 'package:mobile/features/pantry/domain/services/cooking_history_adjustment_planner.dart';

import '../../../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 9);

  group('InventoryTransactionCoordinator', () {
    test('commits Pantry and one History entry, then replays retry', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
      );
      final result = await harness.coordinator.completeCooking(
        _cooking(
          changes: const <PantryQuantityChange>[
            PantryQuantityChange(
              ingredientId: 'egg',
              ingredientName: 'Egg',
              unit: 'piece',
              beforeQuantity: 10,
              afterQuantity: 6,
            ),
          ],
          at: now,
        ),
      );

      expect(result.outcome, InventoryTransactionOutcome.committed);
      expect(result.snapshot.revision, 1);
      expect(result.snapshot.pantry.single.quantity, 6);
      expect(result.snapshot.history, hasLength(1));
      expect(
        result.snapshot.history.single.originatingTransactionId,
        result.transaction!.transactionId,
      );

      await harness.coordinator.completePresentation(
        result.transaction!.transactionId,
      );
      final retry = await harness.coordinator.completeCooking(
        result.transaction!,
      );

      expect(retry.outcome, InventoryTransactionOutcome.alreadyCommitted);
      expect(retry.snapshot.revision, 1);
      expect(retry.snapshot.history, hasLength(1));
    });

    test('rejects all changes when one lot is stale', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[
          _ingredient('egg', 10, 'piece', now),
          _ingredient('milk', 1000, 'ml', now),
        ],
      );
      final result = await harness.coordinator.completeCooking(
        _cooking(
          changes: const <PantryQuantityChange>[
            PantryQuantityChange(
              ingredientId: 'egg',
              ingredientName: 'Egg',
              unit: 'piece',
              beforeQuantity: 10,
              afterQuantity: 8,
            ),
            PantryQuantityChange(
              ingredientId: 'milk',
              ingredientName: 'Milk',
              unit: 'ml',
              beforeQuantity: 900,
              afterQuantity: 700,
            ),
          ],
          at: now,
        ),
      );

      expect(result.outcome, InventoryTransactionOutcome.conflict);
      expect(result.code, 'pantry_quantity_conflict');
      expect(result.snapshot.pantry.map((item) => item.quantity), <double>[
        10,
        1000,
      ]);
      expect(result.snapshot.history, isEmpty);
      expect(await harness.repository.loadJournal(), isEmpty);
    });

    test(
      'rejects missing, duplicate, mismatched, and invalid changes',
      () async {
        final harness = await _Harness.create(
          now: now,
          pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
        );

        final cases = <(List<PantryQuantityChange>, String)>[
          (
            const <PantryQuantityChange>[
              PantryQuantityChange(
                ingredientId: 'missing',
                ingredientName: 'Missing',
                unit: 'piece',
                beforeQuantity: 1,
                afterQuantity: 0,
              ),
            ],
            'pantry_lot_missing',
          ),
          (
            const <PantryQuantityChange>[
              PantryQuantityChange(
                ingredientId: 'egg',
                ingredientName: 'Egg',
                unit: 'kg',
                beforeQuantity: 10,
                afterQuantity: 9,
              ),
            ],
            'pantry_unit_mismatch',
          ),
          (
            const <PantryQuantityChange>[
              PantryQuantityChange(
                ingredientId: 'egg',
                ingredientName: 'Egg',
                unit: 'piece',
                beforeQuantity: 10,
                afterQuantity: -1,
              ),
            ],
            'invalid_quantity',
          ),
          (
            const <PantryQuantityChange>[
              PantryQuantityChange(
                ingredientId: 'egg',
                ingredientName: 'Egg',
                unit: 'piece',
                beforeQuantity: 10,
                afterQuantity: 9,
              ),
              PantryQuantityChange(
                ingredientId: 'egg',
                ingredientName: 'Egg',
                unit: 'piece',
                beforeQuantity: 10,
                afterQuantity: 8,
              ),
            ],
            'duplicate_or_missing_lot_id',
          ),
        ];

        for (final testCase in cases) {
          final result = await harness.coordinator.completeCooking(
            _cooking(changes: testCase.$1, at: now),
          );
          expect(result.code, testCase.$2);
          expect(result.snapshot.revision, 0);
        }
      },
    );

    test('quick undo restores every lot exactly once', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[
          _ingredient('egg', 10, 'piece', now),
          _ingredient('milk', 1000, 'ml', now),
        ],
      );
      final cooking = await harness.coordinator.completeCooking(
        _cooking(
          changes: const <PantryQuantityChange>[
            PantryQuantityChange(
              ingredientId: 'egg',
              ingredientName: 'Egg',
              unit: 'piece',
              beforeQuantity: 10,
              afterQuantity: 8,
            ),
            PantryQuantityChange(
              ingredientId: 'milk',
              ingredientName: 'Milk',
              unit: 'ml',
              beforeQuantity: 1000,
              afterQuantity: 800,
            ),
          ],
          at: now,
        ),
      );
      await harness.coordinator.completePresentation(
        cooking.transaction!.transactionId,
      );

      final undo = await harness.coordinator.undoCooking(cooking.transaction!);
      expect(undo.outcome, InventoryTransactionOutcome.committed);
      expect(undo.snapshot.pantry.map((item) => item.quantity), <double>[
        10,
        1000,
      ]);
      expect(
        undo.snapshot.history.single.status,
        CookingHistoryStatus.cancelled,
      );
      expect(
        undo.snapshot.history.single.reversedByTransactionId,
        undo.transaction!.transactionId,
      );
      await harness.coordinator.completePresentation(
        undo.transaction!.transactionId,
      );

      final duplicate = await harness.coordinator.undoCooking(
        cooking.transaction!,
      );
      expect(duplicate.outcome, InventoryTransactionOutcome.alreadyUndone);
      expect(duplicate.snapshot.revision, 2);
    });

    test('quick undo is all-or-nothing after one lot changes', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[
          _ingredient('egg', 10, 'piece', now),
          _ingredient('milk', 1000, 'ml', now),
        ],
      );
      final cooking = await harness.coordinator.completeCooking(
        _cooking(
          changes: const <PantryQuantityChange>[
            PantryQuantityChange(
              ingredientId: 'egg',
              ingredientName: 'Egg',
              unit: 'piece',
              beforeQuantity: 10,
              afterQuantity: 8,
            ),
            PantryQuantityChange(
              ingredientId: 'milk',
              ingredientName: 'Milk',
              unit: 'ml',
              beforeQuantity: 1000,
              afterQuantity: 800,
            ),
          ],
          at: now,
        ),
      );
      await harness.coordinator.completePresentation(
        cooking.transaction!.transactionId,
      );
      final edited = cooking.snapshot.pantry
          .map(
            (item) => item.id == 'milk'
                ? item.copyWith(quantity: 750, updatedAt: now)
                : item,
          )
          .toList(growable: false);
      final edit = await harness.coordinator.replacePantry(edited);
      await harness.coordinator.completePresentation(
        edit.transaction!.transactionId,
      );

      final undo = await harness.coordinator.undoCooking(cooking.transaction!);
      expect(undo.outcome, InventoryTransactionOutcome.conflict);
      expect(undo.snapshot.pantry.map((item) => item.quantity), <double>[
        8,
        750,
      ]);
      expect(
        undo.snapshot.history.single.status,
        CookingHistoryStatus.completed,
      );
    });

    test('cancel is atomic and duplicate cancel is idempotent', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
      );
      final cooking = await harness.coordinator.completeCooking(
        _cooking(
          changes: const <PantryQuantityChange>[
            PantryQuantityChange(
              ingredientId: 'egg',
              ingredientName: 'Egg',
              unit: 'piece',
              beforeQuantity: 10,
              afterQuantity: 6,
            ),
          ],
          at: now,
        ),
      );
      await harness.coordinator.completePresentation(
        cooking.transaction!.transactionId,
      );
      final entry = cooking.snapshot.history.single;
      final plan = CookingHistoryAdjustmentPlanner(
        clock: FixedAppClock(now.add(const Duration(minutes: 1))),
      ).cancel(entry: entry, pantry: cooking.snapshot.pantry);

      final cancelled = await harness.coordinator.applyHistoryAdjustment(
        plan: plan,
        kind: InventoryTransactionKind.cancelCookingHistory,
      );
      expect(cancelled.outcome, InventoryTransactionOutcome.committed);
      expect(cancelled.snapshot.pantry.single.quantity, 10);
      expect(
        cancelled.snapshot.history.single.status,
        CookingHistoryStatus.cancelled,
      );
      await harness.coordinator.completePresentation(
        cancelled.transaction!.transactionId,
      );

      final duplicate = await harness.coordinator.applyHistoryAdjustment(
        plan: plan,
        kind: InventoryTransactionKind.cancelCookingHistory,
      );
      expect(duplicate.outcome, InventoryTransactionOutcome.alreadyCancelled);
      expect(duplicate.snapshot.pantry.single.quantity, 10);
      expect(duplicate.snapshot.revision, 2);
    });

    test(
      'manual Pantry replacement is revisioned and validates quantities',
      () async {
        final harness = await _Harness.create(
          now: now,
          pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
        );
        final changed = await harness.coordinator.replacePantry(<Ingredient>[
          _ingredient('egg', 12, 'piece', now),
        ]);
        expect(changed.outcome, InventoryTransactionOutcome.committed);
        expect(changed.snapshot.revision, 1);
        expect(changed.snapshot.pantry.single.quantity, 12);

        final invalid = await harness.coordinator.replacePantry(<Ingredient>[
          _ingredient('egg', -1, 'piece', now),
        ]);
        expect(invalid.outcome, InventoryTransactionOutcome.validationFailure);
        expect(invalid.snapshot.pantry.single.quantity, 12);
      },
    );

    test('deletes one History entry without mutating Pantry', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
        history: <CookingHistoryEntry>[
          _history('history-1', now),
          _history('history-2', now),
        ],
      );

      final deleted = await harness.coordinator.deleteCookingHistory(
        'history-1',
      );

      expect(deleted.outcome, InventoryTransactionOutcome.committed);
      expect(
        deleted.transaction!.kind,
        InventoryTransactionKind.deleteCookingHistory,
      );
      expect(deleted.snapshot.pantry.single.quantity, 10);
      expect(deleted.snapshot.history.single.id, 'history-2');
      await harness.coordinator.completePresentation(
        deleted.transaction!.transactionId,
      );

      final duplicate = await harness.coordinator.deleteCookingHistory(
        'history-1',
      );
      expect(duplicate.outcome, InventoryTransactionOutcome.alreadyCommitted);
      expect(duplicate.code, 'history_entry_already_deleted');
      expect(duplicate.snapshot.revision, 1);
    });

    test('clears all History without mutating Pantry', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
        history: <CookingHistoryEntry>[
          _history('history-1', now),
          _history('history-2', now),
        ],
      );

      final cleared = await harness.coordinator.clearCookingHistory();

      expect(cleared.outcome, InventoryTransactionOutcome.committed);
      expect(
        cleared.transaction!.kind,
        InventoryTransactionKind.clearCookingHistory,
      );
      expect(cleared.snapshot.pantry.single.quantity, 10);
      expect(cleared.snapshot.history, isEmpty);
    });

    test('canonical migration is durable, validated, and idempotent', () async {
      final harness = await _Harness.create(
        now: now,
        pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
      );
      final migrated = <Ingredient>[
        _ingredient('egg', 10, 'piece', now).copyWith(
          schemaVersion: 2,
          canonicalIngredientId: 'egg',
          canonicalUnitId: 'piece',
          canonicalMappingStatus: CanonicalMappingStatus.mapped,
        ),
      ];

      final result = await harness.coordinator.migrateCanonicalIngredients(
        pantry: migrated,
        history: const <CookingHistoryEntry>[],
        targetSchemaVersion: 2,
      );
      expect(result.outcome, InventoryTransactionOutcome.committed);
      expect(result.snapshot.revision, 1);
      expect(result.snapshot.pantry.single.canonicalIngredientId, 'egg');
      await harness.coordinator.completePresentation(
        result.transaction!.transactionId,
      );

      final duplicate = await harness.coordinator.migrateCanonicalIngredients(
        pantry: result.snapshot.pantry,
        history: result.snapshot.history,
        targetSchemaVersion: 2,
      );
      expect(duplicate.outcome, InventoryTransactionOutcome.alreadyCommitted);
      expect(duplicate.code, 'canonical_migration_not_required');
      expect(duplicate.snapshot.revision, 1);

      final invalid = await harness.coordinator.migrateCanonicalIngredients(
        pantry: <Ingredient>[_ingredient('egg', 10, 'piece', now)],
        history: const <CookingHistoryEntry>[],
        targetSchemaVersion: 2,
      );
      expect(invalid.outcome, InventoryTransactionOutcome.validationFailure);
      expect(invalid.snapshot.revision, 1);
    });
  });
}

class _Harness {
  const _Harness({required this.repository, required this.coordinator});

  final HiveInventoryCommitRepository repository;
  final InventoryTransactionCoordinator coordinator;

  static Future<_Harness> create({
    required DateTime now,
    required List<Ingredient> pantry,
    List<CookingHistoryEntry> history = const <CookingHistoryEntry>[],
  }) async {
    final store = InMemoryInventoryStore(
      legacyPantry: pantry,
      legacyHistory: history,
    );
    final clock = FixedAppClock(now);
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: clock,
    );
    await repository.recoverPendingTransactions();
    return _Harness(
      repository: repository,
      coordinator: InventoryTransactionCoordinator(
        repository: repository,
        clock: clock,
        transactionIdGenerator: SequenceTransactionIdGenerator(),
      ),
    );
  }
}

CookingHistoryEntry _history(String id, DateTime now) {
  return CookingHistoryEntry(
    originatingTransactionId: id,
    id: id,
    recipeId: 'omelette',
    recipeName: 'Omelette',
    servings: 2,
    changes: const <CookingHistoryChange>[
      CookingHistoryChange(
        ingredientId: 'egg',
        ingredientName: 'Egg',
        unit: 'egg',
        beforeQuantity: 10,
        originalAfterQuantity: 8,
        afterQuantity: 8,
        canonicalIngredientId: 'egg',
        canonicalUnitId: 'egg',
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    ],
    createdAt: now,
    updatedAt: now,
    status: CookingHistoryStatus.completed,
  );
}

Ingredient _ingredient(String id, double quantity, String unit, DateTime now) {
  return Ingredient(
    id: id,
    name: id,
    category: 'test',
    emoji: 'x',
    quantity: quantity,
    unit: unit,
    createdAt: now,
    updatedAt: now,
  );
}

PantryQuantityTransaction _cooking({
  required List<PantryQuantityChange> changes,
  required DateTime at,
}) {
  return PantryQuantityTransaction(
    recipeId: 'recipe',
    recipeName: 'Recipe',
    servings: 2,
    changes: changes,
    createdAt: at,
  );
}
