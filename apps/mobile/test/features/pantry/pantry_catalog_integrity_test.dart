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
      expect(registry.areCompatibleIds('chicken', 'chicken_breast'), isTrue);
      expect(registry.resolve('Duck').ingredient?.id, 'duck');
      expect(registry.resolve('Tilapia').ingredient?.id, 'tilapia');
      expect(registry.resolve('ปลาทับทิม').ingredient?.id, 'tilapia');
      expect(registry.areCompatibleIds('fish', 'tilapia'), isFalse);
      expect(registry.areCompatibleIds('mackerel', 'tilapia'), isFalse);
    },
  );

  test(
    'Thai Pantry Essentials have canonical names and useful aliases',
    () async {
      final registry = await IngredientCatalog().loadRegistry();
      const essentials = <String>[
        'rice',
        'egg',
        'pork',
        'chicken',
        'shrimp',
        'mackerel',
        'tilapia',
        'sea_bass',
        'salmon',
        'tofu',
        'garlic',
        'chili',
        'shallot',
        'coriander',
        'lime',
        'lemongrass',
        'galangal',
        'kaffir_lime_leaf',
        'fish_sauce',
        'soy_sauce',
        'oyster_sauce',
        'palm_sugar',
        'coconut_milk',
      ];

      for (final id in essentials) {
        final ingredient = registry.byId(id);
        expect(ingredient, isNotNull, reason: '$id must be canonical');
        expect(
          ingredient!.displayName().trim(),
          isNotEmpty,
          reason: '$id must have a Thai display name',
        );
        expect(
          ingredient.aliases,
          isNotEmpty,
          reason: '$id must have at least one useful alias',
        );
      }
    },
  );
}
