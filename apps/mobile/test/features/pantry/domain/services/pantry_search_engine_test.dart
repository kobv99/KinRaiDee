import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/features/pantry/domain/models/food_category.dart';
import 'package:mobile/features/pantry/domain/services/pantry_search_engine.dart';

void main() {
  group('PantrySearchEngine', () {
    test('puts an exact name match before broader matches', () {
      final ranked = PantrySearchEngine.rankCatalogItems(
        allFoodCatalogItems,
        'กุ้ง',
      );

      expect(ranked, isNotEmpty);
      expect(ranked.first.item.name, 'กุ้ง');
    });

    test('finds catalog items through aliases', () {
      final porkMince = allFoodCatalogItems.firstWhere(
        (entry) => entry.item.name == 'หมูสับ',
      );

      final match = PantrySearchEngine.matchCatalogItem(porkMince, 'หมูบด');

      expect(match.isMatch, isTrue);
      expect(match.type, PantrySearchMatchType.exactAlias);
      expect(match.matchedAlias, 'หมูบด');
    });

    test('finds a close Thai spelling through fuzzy matching', () {
      final basil = allFoodCatalogItems.firstWhere(
        (entry) => entry.item.name == 'ใบกะเพรา',
      );

      final match = PantrySearchEngine.matchCatalogItem(basil, 'กระเพา');

      expect(match.isMatch, isTrue);
      expect(
        match.type,
        anyOf(
          PantrySearchMatchType.fuzzyName,
          PantrySearchMatchType.fuzzyAlias,
        ),
      );
    });

    test('ranks prefix matches before contains matches', () {
      final ranked = PantrySearchEngine.rankCatalogItems(
        allFoodCatalogItems,
        'หมู',
      );

      expect(ranked, isNotEmpty);
      expect(ranked.first.item.name.startsWith('หมู'), isTrue);
    });

    test('uses catalog aliases when searching pantry ingredients', () {
      final now = DateTime(2026, 7, 23);
      final ingredient = Ingredient(
        id: '1',
        name: 'หมูสับ',
        category: 'เนื้อสัตว์',
        emoji: '🐷',
        quantity: 1,
        unit: 'กิโลกรัม',
        createdAt: now,
        updatedAt: now,
      );

      final match = PantrySearchEngine.matchIngredient(ingredient, 'หมูบด');

      expect(match.isMatch, isTrue);
      expect(match.matchedAlias, 'หมูบด');
    });
  });
}
