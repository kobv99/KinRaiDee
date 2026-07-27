import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/shopping/data/repositories/local_shopping_repository.dart';

import '../../support/inventory_test_support.dart';
import '../../support/shopping_ui_test_support.dart';

void main() {
  test('unfinished lists hide empty lists from the actionable projection', () async {
    final now = DateTime.utc(2026, 7, 27, 10);
    final empty = testShoppingList(now: now, items: const []);
    final active = testShoppingList(
      now: now.subtract(const Duration(minutes: 1)),
      items: [
        testShoppingItem(
          id: 'egg-active',
          canonicalId: 'egg',
          name: 'Egg',
          quantity: 2,
          unit: 'piece',
          category: testShoppingList(now: now).items.first.category,
          recipeIds: const <String>['omelette'],
          now: now,
        ),
      ],
    ).copyWith(name: 'Active list');
    final repository = HiveInventoryCommitRepository(
      store: InMemoryInventoryStore(
        envelope: InventoryStateEnvelope.initial(
          createdAt: now,
          shoppingLists: [
            empty.copyWith(id: 'empty-list', name: 'Empty list'),
            active.copyWith(id: 'active-list'),
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
            testShoppingList(now: now, items: const []).copyWith(
              id: 'completed-list',
              name: 'Completed list',
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
