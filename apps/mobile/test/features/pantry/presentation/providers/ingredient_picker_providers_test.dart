import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/features/pantry/presentation/providers/ingredient_picker_providers.dart';
import 'package:mobile/features/recipe/data/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('taxonomy navigation (real registry)', () {
    test('exactly 9 root family cards, in registry-derived order', () async {
      final registry = await IngredientCatalog().loadRegistry();
      final container = ProviderContainer(
        overrides: [
          canonicalIngredientRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      final roots = container.read(rootIngredientFamiliesProvider);

      expect(roots, hasLength(9));
      expect(roots.map((r) => r.id).toSet(), <String>{
        'pork_family',
        'chicken_family',
        'beef_family',
        'fish_family',
        'shrimp_family',
        'crab_family',
        'squid_family',
        'shellfish_family',
        'other_seafood_family',
      });
      expect(
        roots.every((r) => r.nodeType == CanonicalIngredientNodeType.family),
        isTrue,
      );
      expect(roots.every((r) => r.parentId == null), isTrue);
      // Sorted by display name — deterministic and not a hardcoded id order.
      final names = roots.map((r) => r.displayName()).toList();
      expect(names, List<String>.from(names)..sort());
    });

    test(
      'opening fish reveals its generic, form, and nested families',
      () async {
        final registry = await IngredientCatalog().loadRegistry();
        final container = ProviderContainer(
          overrides: [
            canonicalIngredientRegistryProvider.overrideWithValue(registry),
          ],
        );
        addTearDown(container.dispose);

        final children = container.read(
          ingredientFamilyChildrenProvider('fish_family'),
        );
        final ids = children.map((c) => c.id).toSet();

        expect(
          ids,
          containsAll(<String>[
            'fish',
            'fish_fillet',
            'freshwater_fish_family',
            'sea_fish_family',
          ]),
        );
      },
    );

    test(
      'arbitrary-depth traversal reaches species under sea_fish_family',
      () async {
        final registry = await IngredientCatalog().loadRegistry();
        final container = ProviderContainer(
          overrides: [
            canonicalIngredientRegistryProvider.overrideWithValue(registry),
          ],
        );
        addTearDown(container.dispose);

        final seaFishChildren = container.read(
          ingredientFamilyChildrenProvider('sea_fish_family'),
        );

        expect(
          seaFishChildren.map((c) => c.id).toSet(),
          containsAll(<String>['sea_bass', 'mackerel', 'salmon']),
        );
        expect(
          seaFishChildren.every(
            (c) => c.nodeType == CanonicalIngredientNodeType.ingredient,
          ),
          isTrue,
        );
      },
    );

    test('root-first breadcrumb for a nested species', () async {
      final registry = await IngredientCatalog().loadRegistry();
      expect(registry.ancestorChainFor('mackerel'), <String>[
        'fish_family',
        'sea_fish_family',
      ]);
    });

    test('family cards are never selectable ingredients themselves', () async {
      final registry = await IngredientCatalog().loadRegistry();
      final container = ProviderContainer(
        overrides: [
          canonicalIngredientRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      final roots = container.read(rootIngredientFamiliesProvider);
      for (final root in roots) {
        expect(root.canSelectAsMainIngredient, isFalse);
        expect(root.taxonomyType, isNull);
      }
    });

    test(
      'every root family opens and contains at least one selectable descendant',
      () async {
        final registry = await IngredientCatalog().loadRegistry();
        final container = ProviderContainer(
          overrides: [
            canonicalIngredientRegistryProvider.overrideWithValue(registry),
          ],
        );
        addTearDown(container.dispose);

        final roots = container.read(rootIngredientFamiliesProvider);
        for (final root in roots) {
          final hasSelectableDescendant = registry.ingredients.any(
            (ingredient) =>
                ingredient.nodeType == CanonicalIngredientNodeType.ingredient &&
                registry.ancestorIdsFor(ingredient.id).contains(root.id),
          );
          expect(
            hasSelectableDescendant,
            isTrue,
            reason: '${root.id} has no selectable descendant',
          );
        }
      },
    );
  });

  group('IngredientPickerSelectionNotifier', () {
    test('starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(ingredientPickerSelectionProvider), isEmpty);
    });

    test('toggle selects, then deselects the same id without duplicating', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        ingredientPickerSelectionProvider.notifier,
      );

      notifier.toggle('pork');
      notifier.toggle('pork');
      expect(container.read(ingredientPickerSelectionProvider), isEmpty);

      notifier.toggle('pork');
      notifier.toggle('pork');
      notifier.toggle('pork');
      expect(container.read(ingredientPickerSelectionProvider), <String>{
        'pork',
      });
    });

    test(
      'selecting across multiple families accumulates without duplicates',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(
          ingredientPickerSelectionProvider.notifier,
        );

        notifier.toggle('chicken_breast');
        notifier.toggle('chicken_drumstick');
        notifier.toggle('pork_belly');
        notifier.toggle('mackerel');
        notifier.toggle('chicken_breast'); // no-op re-add attempt guard below
        notifier.toggle('chicken_breast'); // toggled back on

        expect(container.read(ingredientPickerSelectionProvider), <String>{
          'chicken_breast',
          'chicken_drumstick',
          'pork_belly',
          'mackerel',
        });
      },
    );

    test('clear empties the session (used on cancel/commit)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        ingredientPickerSelectionProvider.notifier,
      );

      notifier.toggle('pork');
      notifier.toggle('chicken');
      notifier.clear();

      expect(container.read(ingredientPickerSelectionProvider), isEmpty);
    });

    test('invalidating the provider resets state for a new session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(ingredientPickerSelectionProvider.notifier).toggle('pork');
      expect(container.read(ingredientPickerSelectionProvider), isNotEmpty);

      container.invalidate(ingredientPickerSelectionProvider);

      expect(container.read(ingredientPickerSelectionProvider), isEmpty);
    });
  });

  group('pantryCanonicalIngredientIdsProvider', () {
    test('reflects canonicalIngredientId, not display name', () {
      final now = DateTime(2026, 8, 4);
      final container = ProviderContainer(
        overrides: [
          pantryProvider.overrideWith(() => _FakePantryNotifier(now)),
        ],
      );
      addTearDown(container.dispose);

      final ids = container.read(pantryCanonicalIngredientIdsProvider);

      expect(ids, <String>{'pork_belly'});
    });
  });
}

class _FakePantryNotifier extends PantryNotifier {
  _FakePantryNotifier(this.now);
  final DateTime now;

  @override
  List<Ingredient> build() {
    return <Ingredient>[
      Ingredient(
        id: 'lot-1',
        name: 'หมูสามชั้น',
        category: 'protein',
        emoji: '',
        quantity: 300,
        unit: 'กรัม',
        createdAt: now,
        updatedAt: now,
        canonicalIngredientId: 'pork_belly',
        canonicalUnitId: 'gram',
        canonicalMappingStatus: CanonicalMappingStatus.mapped,
      ),
    ];
  }
}
