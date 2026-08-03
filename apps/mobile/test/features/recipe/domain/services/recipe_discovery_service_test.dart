import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/services/recipe_discovery_service.dart';

void main() {
  const service = RecipeDiscoveryService();

  test('does not return the full database without search or filters', () {
    final results = service.discover(
      recipes: <Recipe>[_recipe(id: 'one', name: 'เมนูหนึ่ง')],
      criteria: const RecipeDiscoveryCriteria(),
    );

    expect(results, isEmpty);
  });

  test('ranks exact recipe title and exact ingredient matches first', () {
    final recipes = <Recipe>[
      _recipe(
        id: 'partial-title',
        name: 'ไข่เจียวสมุนไพร',
        heroId: 'tofu',
        heroName: 'เต้าหู้',
      ),
      _recipe(
        id: 'exact-supporting-ingredient',
        name: 'ข้าวผัด',
        heroId: 'rice',
        heroName: 'ข้าว',
        extraIngredients: const <RecipeIngredient>[
          RecipeIngredient(id: 'egg', name: 'ไข่', quantity: 1, unit: 'ฟอง'),
        ],
      ),
      _recipe(
        id: 'exact-hero-ingredient',
        name: 'อาหารเช้า',
        heroId: 'egg',
        heroName: 'ไข่',
      ),
      _recipe(id: 'exact-title', name: 'ไข่'),
    ];

    final results = service.discover(
      recipes: recipes,
      criteria: const RecipeDiscoveryCriteria(query: 'ไข่'),
    );

    expect(results.map((result) => result.recipe.id), <String>[
      'exact-title',
      'exact-hero-ingredient',
      'exact-supporting-ingredient',
      'partial-title',
    ]);
    expect(results.first.matchType, RecipeDiscoveryMatchType.exactTitle);
  });

  test('combines time, difficulty, method and category filters', () {
    final recipes = <Recipe>[
      _recipe(
        id: 'match',
        name: 'เมนูที่ตรง',
        category: 'อาหารไทย',
        difficulty: 'easy',
        cookTimeMinutes: 20,
        cookingMethods: const <String>['ผัด'],
      ),
      _recipe(
        id: 'too-slow',
        name: 'เมนูช้า',
        category: 'อาหารไทย',
        difficulty: 'easy',
        cookTimeMinutes: 40,
        cookingMethods: const <String>['ผัด'],
      ),
      _recipe(
        id: 'wrong-method',
        name: 'เมนูต้ม',
        category: 'อาหารไทย',
        difficulty: 'easy',
        cookTimeMinutes: 15,
        cookingMethods: const <String>['ต้ม'],
      ),
    ];

    final results = service.discover(
      recipes: recipes,
      criteria: const RecipeDiscoveryCriteria(
        maxCookTimeMinutes: 20,
        difficulty: 'easy',
        cookingMethod: 'ผัด',
        category: 'อาหารไทย',
      ),
    );

    expect(results.map((result) => result.recipe.id), <String>['match']);
    expect(results.single.matchType, RecipeDiscoveryMatchType.filterOnly);
  });

  test(
    'main ingredient options exclude category nodes and filter exact heroes',
    () {
      final registry = CanonicalIngredientRegistry(
        ingredients: <CanonicalIngredient>[
          _canonical(
            'fish',
            'ปลา',
            nodeType: CanonicalIngredientNodeType.family,
            selectableAsMainIngredient: false,
          ),
          _canonical('mackerel', 'ปลาทู', parentId: 'fish'),
          _canonical('rice', 'ข้าว'),
        ],
      );
      final recipes = <Recipe>[
        _recipe(
          id: 'generic-fish',
          name: 'เมนูปลาทั่วไป',
          heroId: 'fish',
          heroName: 'ปลา',
        ),
        _recipe(
          id: 'mackerel-hero',
          name: 'เมี่ยงปลาทู',
          heroId: 'mackerel',
          heroName: 'ปลาทู',
        ),
        _recipe(
          id: 'mackerel-supporting-only',
          name: 'ข้าวคลุกปลา',
          heroId: 'rice',
          heroName: 'ข้าว',
          extraIngredients: const <RecipeIngredient>[
            RecipeIngredient(
              id: 'mackerel',
              name: 'ปลาทู',
              quantity: 1,
              unit: 'ตัว',
            ),
          ],
        ),
      ];

      final options = service.mainIngredients(recipes, registry: registry);
      final results = service.discover(
        recipes: recipes,
        criteria: const RecipeDiscoveryCriteria(mainIngredientId: 'mackerel'),
        registry: registry,
      );

      expect(options.map((option) => option.id), <String>['rice', 'mackerel']);
      expect(options.any((option) => option.id == 'fish'), isFalse);
      expect(results.map((result) => result.recipe.id), <String>[
        'mackerel-hero',
      ]);
    },
  );

  test('facet values are ordered by frequency then label', () {
    final recipes = <Recipe>[
      _recipe(id: 'one', name: 'One', category: 'จานเดียว'),
      _recipe(id: 'two', name: 'Two', category: 'ซุป'),
      _recipe(id: 'three', name: 'Three', category: 'จานเดียว'),
      _recipe(id: 'four', name: 'Four', category: 'แกง'),
    ];

    expect(service.categories(recipes), <String>['จานเดียว', 'ซุป', 'แกง']);
  });
}

Recipe _recipe({
  required String id,
  required String name,
  String category = 'ทั่วไป',
  String difficulty = 'easy',
  int cookTimeMinutes = 15,
  List<String> cookingMethods = const <String>['ผัด'],
  String heroId = 'rice',
  String heroName = 'ข้าว',
  List<RecipeIngredient> extraIngredients = const <RecipeIngredient>[],
}) {
  return Recipe(
    id: id,
    name: name,
    category: category,
    difficulty: difficulty,
    cookTimeMinutes: cookTimeMinutes,
    cookingMethods: cookingMethods,
    heroIngredientId: heroId,
    heroIngredientName: heroName,
    ingredients: <RecipeIngredient>[
      RecipeIngredient(
        id: heroId,
        name: heroName,
        quantity: 1,
        unit: 'ส่วน',
        role: RecipeIngredientRole.primary,
      ),
      ...extraIngredients,
    ],
    steps: const <String>['ปรุงให้สุก'],
  );
}

CanonicalIngredient _canonical(
  String id,
  String thaiName, {
  String? parentId,
  CanonicalIngredientNodeType nodeType = CanonicalIngredientNodeType.ingredient,
  bool selectableAsMainIngredient = true,
}) {
  return CanonicalIngredient(
    id: id,
    canonicalName: id,
    localizedNames: <String, String>{'th': thaiName},
    aliases: const <String>[],
    searchKeywords: const <String>[],
    category: 'test',
    defaultStorageType: IngredientStorageType.refrigerated,
    defaultPurchaseUnitId: 'piece',
    defaultInventoryUnitId: 'piece',
    parentId: parentId,
    nodeType: nodeType,
    selectableAsMainIngredient: selectableAsMainIngredient,
  );
}
