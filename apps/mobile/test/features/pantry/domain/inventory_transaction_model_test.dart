import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/pantry/domain/models/inventory_transaction_record.dart';
import 'package:mobile/features/pantry/domain/models/pantry_quantity_transaction.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26);

  test('state machine accepts only RFC-0003 transitions', () {
    expect(
      isLegalInventoryTransition(
        InventoryTransactionState.created,
        InventoryTransactionState.validating,
      ),
      isTrue,
    );
    expect(
      isLegalInventoryTransition(
        InventoryTransactionState.committed,
        InventoryTransactionState.failed,
      ),
      isFalse,
    );
    expect(
      isTerminalInventoryTransactionState(InventoryTransactionState.completed),
      isTrue,
    );

    final record = _record(now);
    expect(
      () => record.transitionTo(InventoryTransactionState.committed, at: now),
      throwsStateError,
    );
  });

  test('journal record survives JSON round trip with one state', () {
    final before = InventoryStateEnvelope.initial(
      createdAt: now,
      pantry: <Ingredient>[_ingredient(now)],
    );
    final after = before
        .copyWith(
          revision: 1,
          lastAppliedTransactionId: 'tx',
          updatedAt: now.add(const Duration(minutes: 1)),
        )
        .withComputedChecksum();
    final original = InventoryTransactionRecord(
      transactionId: 'tx',
      kind: InventoryTransactionKind.completeCooking,
      state: InventoryTransactionState.prepared,
      baseRevision: 0,
      targetRevision: 1,
      createdAt: now,
      updatedAt: now,
      commandChecksum: 'command',
      beforeChecksum: before.checksum,
      afterChecksum: after.checksum,
      beforeEnvelope: before,
      afterEnvelope: after,
    );

    final restored = InventoryTransactionRecord.fromJson(original.toJson());

    expect(restored.state, InventoryTransactionState.prepared);
    expect(restored.beforeEnvelope!.hasValidChecksum, isTrue);
    expect(restored.afterEnvelope!.revision, 1);
  });

  test('envelope checksum is canonical and detects mutation', () {
    final envelope = InventoryStateEnvelope.initial(
      createdAt: now,
      pantry: <Ingredient>[_ingredient(now)],
    );
    final reordered = <String, dynamic>{
      'history': const <dynamic>[],
      'pantry': envelope.pantry.map((item) => item.toJson()).toList(),
      'updatedAt': now.toIso8601String(),
      'lastAppliedTransactionId': '',
      'revision': 0,
      'capabilities': const <String>[],
      'minimumReaderVersion': 1,
      'envelopeVersion': 1,
    };

    expect(calculateChecksum(reordered), envelope.checksum);
    expect(envelope.hasValidChecksum, isTrue);
    final corrupt = InventoryStateEnvelope.fromJson(
      envelope.toJson()..['revision'] = 2,
    );
    expect(corrupt.hasValidChecksum, isFalse);
    expect(() => calculateChecksum(double.nan), throwsFormatException);
  });

  test('quantity transaction serializes explicit identity and revision', () {
    final original = PantryQuantityTransaction(
      transactionId: 'tx',
      expectedRevision: 7,
      kind: InventoryTransactionKind.undoCooking,
      reversesTransactionId: 'origin',
      targetHistoryEntryId: 'history',
      recipeId: 'recipe',
      recipeName: 'Recipe',
      servings: 2,
      changes: const <PantryQuantityChange>[
        PantryQuantityChange(
          ingredientId: 'egg',
          ingredientName: 'Egg',
          unit: 'piece',
          beforeQuantity: 6,
          afterQuantity: 10,
        ),
      ],
      createdAt: now,
    );

    final restored = PantryQuantityTransaction.fromJson(original.toJson());

    expect(restored.transactionId, 'tx');
    expect(restored.expectedRevision, 7);
    expect(restored.kind, InventoryTransactionKind.undoCooking);
    expect(restored.reversesTransactionId, 'origin');
    expect(restored.changes.single.afterQuantity, 10);
  });
}

InventoryTransactionRecord _record(DateTime now) {
  return InventoryTransactionRecord(
    transactionId: 'tx',
    kind: InventoryTransactionKind.completeCooking,
    state: InventoryTransactionState.created,
    baseRevision: 0,
    targetRevision: 1,
    createdAt: now,
    updatedAt: now,
    commandChecksum: 'command',
    beforeChecksum: 'before',
    afterChecksum: 'after',
  );
}

Ingredient _ingredient(DateTime now) {
  return Ingredient(
    id: 'egg',
    name: 'Egg',
    category: 'test',
    emoji: 'x',
    quantity: 10,
    unit: 'piece',
    createdAt: now,
    updatedAt: now,
  );
}
