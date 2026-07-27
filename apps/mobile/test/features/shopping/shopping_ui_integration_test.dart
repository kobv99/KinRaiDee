import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item_status.dart';

import '../../support/shopping_ui_test_support.dart';

void main() {
  testWidgets(
    'purchase UI persists Shopping and Pantry together across restart',
    (tester) async {
      final now = DateTime.utc(2026, 7, 26, 10);
      final harness = await ShoppingUiHarness.create(
        list: testShoppingList(
          now: now,
          items: [
            testShoppingItem(
              id: 'egg-item',
              canonicalId: 'egg',
              name: 'Egg',
              quantity: 6,
              unit: 'piece',
              category: testShoppingList(now: now).items.first.category,
              recipeIds: const <String>['omelette'],
              now: now,
            ),
          ],
        ),
      );
      addTearDown(harness.dispose);
      await harness.pump(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-check-egg-item')),
      );
      await tester.pumpAndSettle();

      final restartedRepository = HiveInventoryCommitRepository(
        store: harness.store,
        clock: FixedAppClock(now),
      );
      final recovery = await restartedRepository.recoverPendingTransactions();
      expect(recovery.allowsMutation, isTrue);
      expect(recovery.snapshot.pantry.single.quantity, 6);
      expect(
        recovery.snapshot.shoppingLists.single.items.single.status,
        ShoppingItemStatus.purchased,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('shopping-check-egg-item')),
      );
      await tester.pumpAndSettle();

      final afterUndo = await restartedRepository.recoverPendingTransactions();
      expect(afterUndo.snapshot.pantry, isEmpty);
      expect(
        afterUndo.snapshot.shoppingLists.single.items.single.status,
        ShoppingItemStatus.active,
      );
    },
  );
}
