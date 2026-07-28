import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_category.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_item.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_list.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_source.dart';
import 'package:mobile/features/shopping/domain/entities/shopping_status.dart';

void main() {
  test('ShoppingList and ShoppingItem survive JSON round trip', () {
    final now = DateTime.utc(2026, 7, 26, 10);
    final original = ShoppingList(
      id: 'weekly',
      name: 'Weekly',
      status: ShoppingStatus.archived,
      revision: 3,
      items: <ShoppingItem>[
        ShoppingItem(
          id: 'weekly::egg::piece',
          canonicalIngredientId: 'egg',
          displayName: 'Egg',
          quantity: 6,
          unitId: 'piece',
          category: ShoppingCategory.protein,
          source: ShoppingSource.recipe,
          sourceReferenceId: 'omelette',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final restored = ShoppingList.fromJson(original.toJson());

    expect(restored.id, 'weekly');
    expect(restored.status, ShoppingStatus.archived);
    expect(restored.revision, 3);
    expect(restored.items.single.canonicalIngredientId, 'egg');
    expect(restored.items.single.unitId, 'piece');
    expect(restored.items.single.source, ShoppingSource.recipe);
    expect(restored.toJson(), original.toJson());
  });

  test('unknown persisted enum values fail closed', () {
    final now = DateTime.utc(2026, 7, 26);
    final list = ShoppingList(
      id: 'list',
      name: 'List',
      items: const <ShoppingItem>[],
      createdAt: now,
      updatedAt: now,
    ).toJson();

    expect(
      () => ShoppingList.fromJson(list..['status'] = 'purchased'),
      throwsFormatException,
    );
  });

  test('canonical categories map deterministically', () {
    expect(
      ShoppingCategory.fromCanonicalCategory('vegetable'),
      ShoppingCategory.produce,
    );
    expect(
      ShoppingCategory.fromCanonicalCategory('protein'),
      ShoppingCategory.protein,
    );
    expect(
      ShoppingCategory.fromCanonicalCategory('not-in-catalog'),
      ShoppingCategory.other,
    );
  });
}
