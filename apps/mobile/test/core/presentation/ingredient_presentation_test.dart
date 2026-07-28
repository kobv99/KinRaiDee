import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/presentation/ingredient_presentation.dart';

void main() {
  final registry = CanonicalIngredientRegistry(
    ingredients: <CanonicalIngredient>[
      CanonicalIngredient(
        id: 'fish_sauce',
        canonicalName: 'fish sauce',
        localizedNames: const <String, String>{'th': 'น้ำปลา'},
        aliases: const <String>['nam pla'],
        searchKeywords: const <String>[],
        category: 'seasoning',
        defaultStorageType: IngredientStorageType.pantry,
        defaultPurchaseUnitId: 'bottle',
        defaultInventoryUnitId: 'milliliter',
        emoji: '🧂',
      ),
    ],
  );

  Ingredient ingredient({
    required String id,
    required String name,
    required String category,
    required String emoji,
    String canonicalIngredientId = '',
  }) {
    final now = DateTime.utc(2026, 7, 27);
    return Ingredient(
      id: id,
      name: name,
      category: category,
      emoji: emoji,
      quantity: 1,
      unit: 'ขวด',
      createdAt: now,
      updatedAt: now,
      canonicalIngredientId: canonicalIngredientId,
    );
  }

  group('IngredientPresentation', () {
    test('stable canonical ID overrides Shopping presentation metadata', () {
      final shoppingImported = ingredient(
        id: 'shopping',
        name: 'น้ำปลา',
        category: 'เครื่องปรุง',
        emoji: '🫙',
        canonicalIngredientId: 'fish_sauce',
      );
      final manual = ingredient(
        id: 'manual',
        name: 'น้ำปลา',
        category: 'seasoning',
        emoji: '',
        canonicalIngredientId: 'fish_sauce',
      );

      expect(
        IngredientPresentation.emoji(shoppingImported, registry),
        IngredientPresentation.emoji(manual, registry),
      );
      expect(IngredientPresentation.emoji(shoppingImported, registry), '🧂');
      expect(
        IngredientPresentation.category(shoppingImported, registry),
        'เครื่องปรุง',
      );
    });

    test('legacy records resolve through localized-name alias fallback', () {
      final legacy = ingredient(
        id: 'legacy',
        name: 'น้ำปลา',
        category: 'seasoning',
        emoji: '🫙',
      );

      expect(IngredientPresentation.emoji(legacy, registry), '🧂');
      expect(IngredientPresentation.category(legacy, registry), 'เครื่องปรุง');
    });

    test('localizes approved category keys centrally', () {
      expect(IngredientPresentation.localizedCategory('seasoning'), 'เครื่องปรุง');
      expect(IngredientPresentation.localizedCategory('protein'), 'โปรตีน');
      expect(IngredientPresentation.localizedCategory('seafood'), 'อาหารทะเล');
    });

    test('unknown custom ingredients retain safe stored fallbacks', () {
      final custom = ingredient(
        id: 'custom',
        name: 'สูตรพิเศษ',
        category: 'หมวดของฉัน',
        emoji: '⭐',
      );

      expect(IngredientPresentation.emoji(custom, registry), '⭐');
      expect(IngredientPresentation.category(custom, registry), 'หมวดของฉัน');
    });
  });
}
