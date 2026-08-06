import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pantry/domain/models/food_category.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every selectable Pantry catalog item resolves canonically', () async {
    final registry = await IngredientCatalog().loadRegistry();

    for (final entry in allFoodCatalogItems) {
      expect(
        registry.resolve(entry.item.name).ingredient,
        isNotNull,
        reason:
            '${entry.category}/${entry.item.name} must resolve before it can be created',
      );
    }
  });

  test(
    'critical English and localized aliases resolve deterministically',
    () async {
      final registry = await IngredientCatalog().loadRegistry();

      expect(
        registry.resolve('Chicken Breast').ingredient?.id,
        'chicken_breast',
      );
      expect(registry.resolve('Duck').ingredient?.id, 'duck');
      expect(registry.resolve('Tilapia').ingredient?.id, 'tilapia');
      // 'ปลาทับทิม' (red tilapia) moved from a tilapia alias to its own
      // manifest id, red_tilapia — see the semantic migration rule.
      expect(registry.resolve('ปลาทับทิม').ingredient?.id, 'red_tilapia');
    },
  );
}
