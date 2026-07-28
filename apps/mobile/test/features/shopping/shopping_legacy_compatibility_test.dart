import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/shopping/application/shopping_providers.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item_status.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_purchase.dart';
import 'package:mobile/features/shopping/domain/models/shopping_mutation.dart';

import '../../support/shopping_ui_test_support.dart';

void main() {
  test('active-only upsert preserves hidden legacy purchase records', () async {
    final now = DateTime.utc(2026, 7, 27, 10);
    final active = _activeItem(now);
    final legacy = _legacyItem(now);
    final harness = await ShoppingUiHarness.create(
      list: testShoppingList(now: now, items: [active, legacy]),
      at: now,
      seedLegacyShoppingState: true,
    );
    addTearDown(harness.dispose);

    final projected = await harness.lists();
    expect(projected.single.items, [active]);

    final regenerated = projected.single.copyWith(
      revision: projected.single.revision,
      items: [active.copyWith(quantity: 8, updatedAt: now)],
      updatedAt: now,
    );
    final result = await harness.container
        .read(shoppingMutationControllerProvider)
        .execute(ShoppingMutation.upsert(list: regenerated, createdAt: now));

    expect(result.isSuccess, isTrue);
    final raw = await harness.repository.loadConsistentSnapshot();
    expect(raw.shoppingLists.single.items, hasLength(2));
    expect(
      raw.shoppingLists.single.items
          .where((item) => item.status == ShoppingItemStatus.purchased)
          .single
          .id,
      'egg-legacy-purchase',
    );
    expect((await harness.lists()).single.items.single.quantity, 8);
  });

  test('new completion retains legacy Purchase History from journal snapshots', () async {
    final now = DateTime.utc(2026, 7, 27, 10);
    final active = _activeItem(now);
    final legacy = _legacyItem(now);
    final harness = await ShoppingUiHarness.create(
      list: testShoppingList(now: now, items: [active, legacy]),
      at: now,
      seedLegacyShoppingState: true,
    );
    addTearDown(harness.dispose);

    final list = (await harness.lists()).single;
    final completed = await harness.container
        .read(shoppingCompletionControllerProvider)
        .complete(
          listId: list.id,
          expectedListRevision: list.revision,
          itemId: active.id,
          createdAt: now,
        );

    expect(completed.isSuccess, isTrue);
    expect((await harness.lists()).single.items, isEmpty);
    final history = await harness.history();
    expect(history, hasLength(2));
    expect(
      history.map((entry) => entry.pantryTransactionId).toSet(),
      containsAll(<String>{
        'legacy-purchase-transaction',
        completed.transaction!.transactionId,
      }),
    );
  });
}

ShoppingItem _activeItem(DateTime now) {
  return testShoppingItem(
    id: 'egg-active',
    canonicalId: 'egg',
    name: 'Egg',
    quantity: 6,
    unit: 'piece',
    category: testShoppingList(now: now).items.first.category,
    recipeIds: const <String>['omelette'],
    now: now,
  );
}

ShoppingItem _legacyItem(DateTime now) {
  return testShoppingItem(
    id: 'egg-legacy-purchase',
    canonicalId: 'egg',
    name: 'Egg',
    quantity: 2,
    unit: 'piece',
    category: testShoppingList(now: now).items.first.category,
    recipeIds: const <String>['omelette'],
    now: now.subtract(const Duration(days: 1)),
  ).copyWith(
    status: ShoppingItemStatus.purchased,
    purchase: ShoppingPurchase(
      transactionId: 'legacy-purchase-transaction',
      pantryLotId: 'legacy-pantry-lot',
      createdPantryLot: false,
      pantryUnitId: 'piece',
      beforeQuantity: 4,
      afterQuantity: 6,
      purchasedAt: now.subtract(const Duration(days: 1)),
    ),
  );
}
