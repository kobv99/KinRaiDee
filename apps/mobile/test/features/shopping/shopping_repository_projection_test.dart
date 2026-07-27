import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/shopping/data/repositories/local_shopping_repository.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';

import '../../support/inventory_test_support.dart';
import '../../support/shopping_ui_test_support.dart';

void main() {
  test('unfinished lists hide empty lists from the actionable projection', () async {
    final now = DateTime.utc(2026, 7, 27, 10);
    final activeItem = testShoppingItem(
      id: 'egg-active',
      canonicalId: 'egg',
      name: 'Egg',
      quantity: 2,
      unit: 'piece',
      category: testShoppingList(now: now).items.first.category,
      recipeIds: const <String>['omelette'],
      now: now,
    );
    final repository = HiveInventoryCommitRepository(
      store: InMemoryInventoryStore(
        envelope: InventoryStateEnvelope.initial(
          createdAt: now,
          shoppingLists: [
            _list(
              id: 'empty-list',
              name: 'Empty list',
              items: const [],
              now: now,
            ),
            _list(
              id: 'active-list',
              name: 'Active list',
              items: [activeItem],
              now: now.subtract(const Duration(minutes: 1)),
            ),
          ],
        ).toJson(),
      ),
    );

    final lists = await LocalShoppingRepository(repository).getLists();

    expect(lists, hasLength(1));
    expect(lists.single.id, 'active-list');
  });

  test('all-empty lists remain visible for the celebration state', () async {
    final now = DateTime.utc(2026, 7, 27, 10);
    final repository = HiveInventoryCommitRepository(
      store: InMemoryInventoryStore(
        envelope: InventoryStateEnvelope.initial(
          createdAt: now,
          shoppingLists: [
            _list(
              id: 'completed-list',
              name: 'Completed list',
              items: const [],
              now: now,
            ),
          ],
        ).toJson(),
      ),
    );

    final lists = await LocalShoppingRepository(repository).getLists();

    expect(lists, hasLength(1));
    expect(lists.single.items, isEmpty);
  });
}

ShoppingList _list({
  required String id,
  required String name,
  required List<ShoppingItem> items,
  required DateTime now,
}) {
  return ShoppingList(
    id: id,
    name: name,
    items: items,
    createdAt: now,
    updatedAt: now,
  );
}
