import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';

void main() {
  test(
    'Shopping source references preserve envelope checksum after JSON round trip',
    () {
      final now = DateTime.utc(2026, 7, 28, 9);
      final item = ShoppingItem(
        id: 'egg-item',
        canonicalIngredientId: 'egg',
        displayName: 'Egg',
        quantity: 2,
        unitId: 'piece',
        category: ShoppingCategory.protein,
        source: ShoppingSource.recipe,
        sourceReferenceIds: const <String>['omelette'],
        createdAt: now,
        updatedAt: now,
      );
      final envelope = InventoryStateEnvelope.initial(
        createdAt: now,
        shoppingLists: <ShoppingList>[
          ShoppingList(
            id: 'weekly',
            name: 'Weekly',
            items: <ShoppingItem>[item],
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final restored = InventoryStateEnvelope.fromJson(envelope.toJson());
      final restoredItem = restored.shoppingLists.single.items.single;

      expect(restored.hasValidChecksum, isTrue);
      expect(restoredItem.sourceReferenceId, isNull);
      expect(restoredItem.sourceReferenceIds, const <String>['omelette']);
      expect(restored.toJson(), equals(envelope.toJson()));
    },
  );
}
