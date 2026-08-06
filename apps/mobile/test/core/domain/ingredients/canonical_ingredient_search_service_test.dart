import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_search_service.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = CanonicalIngredientSearchService();

  test('exact Thai name matches', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final results = service.search(registry, 'อกไก่');
    expect(results.map((r) => r.ingredient.id), contains('chicken_breast'));
  });

  test('English alias matches', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final results = service.search(registry, 'chicken thigh');
    expect(results.map((r) => r.ingredient.id), contains('chicken_thigh'));
  });

  test('ambiguous partial search "น่อง" returns both น่องไก่ and เนื้อน่องลาย '
      'with distinct breadcrumbs, and does not select anything', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final results = service.search(registry, 'น่อง');
    final byId = {for (final r in results) r.ingredient.id: r};

    expect(byId.containsKey('chicken_drumstick'), isTrue);
    expect(byId.containsKey('beef_shank'), isTrue);
    expect(byId['chicken_drumstick']!.breadcrumb, <String>['ไก่']);
    expect(byId['beef_shank']!.breadcrumb, <String>['เนื้อวัว']);
    // Search itself has no concept of "selection" at all — it only
    // returns data, proving typing alone can never select anything.

    // The UI joins ancestors + the leaf's own name with ' › ' as the full
    // presentation breadcrumb — proving the exact strings the live UAT
    // bug report expected are reachable from this real-registry data.
    String fullBreadcrumb(CanonicalIngredientSearchResult r) =>
        <String>[...r.breadcrumb, r.ingredient.displayName()].join(' › ');
    expect(fullBreadcrumb(byId['chicken_drumstick']!), 'ไก่ › น่องไก่');
    expect(fullBreadcrumb(byId['beef_shank']!), 'เนื้อวัว › เนื้อน่องลาย');
  });

  test('family and category nodes are never returned as results', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final results = service.search(registry, 'หมู'); // matches pork_family's
    // display name too, but only the selectable generic should surface
    final ids = results.map((r) => r.ingredient.id).toSet();

    expect(ids, contains('pork'));
    expect(ids, isNot(contains('pork_family')));
  });

  test('every result is a leaf ingredient node', () async {
    final registry = await IngredientCatalog().loadRegistry();
    for (final query in <String>['ปลา', 'กุ้ง', 'ปู', 'หมึก', 'หอย']) {
      final results = service.search(registry, query);
      for (final result in results) {
        expect(
          result.ingredient.nodeType.name,
          'ingredient',
          reason: '$query matched a non-ingredient node',
        );
      }
    }
  });

  test('empty query returns no results', () async {
    final registry = await IngredientCatalog().loadRegistry();
    expect(service.search(registry, ''), isEmpty);
    expect(service.search(registry, '   '), isEmpty);
  });

  test('root-first breadcrumb for a deeply nested species match', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final results = service.search(registry, 'ปลาทู');
    final mackerel = results.firstWhere((r) => r.ingredient.id == 'mackerel');
    expect(mackerel.breadcrumb, <String>['ปลา', 'ปลาทะเล']);
  });

  test('query "หมูสับ" matches minced pork under หมู', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final results = service.search(registry, 'หมูสับ');
    final match = results.firstWhere((r) => r.ingredient.id == 'minced_pork');
    expect(match.breadcrumb, <String>['หมู']);
    expect(match.ingredient.displayName(), 'หมูสับ');
  });

  test('query "หมูสันใน" finds pork tenderloin (สันในหมู) through its reversed-'
      'wording alias, not just the canonical name', () async {
    final registry = await IngredientCatalog().loadRegistry();
    final results = service.search(registry, 'หมูสันใน');
    final match = results.firstWhere(
      (r) => r.ingredient.id == 'pork_tenderloin',
    );
    expect(match.breadcrumb, <String>['หมู']);
    expect(match.ingredient.displayName(), 'สันในหมู');
  });
}
