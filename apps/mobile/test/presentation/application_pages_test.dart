import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/providers/pantry_provider.dart';
import 'package:mobile/core/time/app_clock.dart';
import 'package:mobile/features/home/presentation/pages/home_page.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';
import 'package:mobile/features/pantry/domain/models/food_category.dart';
import 'package:mobile/features/pantry/domain/repositories/pantry_repository.dart';
import 'package:mobile/features/pantry/presentation/pages/cooking_history_page.dart';
import 'package:mobile/features/pantry/presentation/pages/pantry_page.dart';
import 'package:mobile/features/pantry/presentation/providers/cooking_history_provider.dart';
import 'package:mobile/features/pantry/presentation/providers/pantry_filter_provider.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_match.dart';
import 'package:mobile/features/recipe/domain/entities/smart_recommendation.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_detail_page.dart';
import 'package:mobile/features/recipe/presentation/pages/recipe_page.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_provider.dart';

import '../support/inventory_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 9);

  group('application page integration', () {
    testWidgets('recipe completion and quick undo publish only durable state', (
      tester,
    ) async {
      _useLargeSurface(tester);
      final ingredient = _ingredient(
        id: 'egg-lot',
        name: 'Egg',
        quantity: 10,
        unit: 'piece',
        now: now,
      );
      final harness = await _Harness.create(
        pantry: <Ingredient>[ingredient],
        now: now,
      );
      addTearDown(harness.dispose);
      final recipe = _recipe();

      await _pumpPage(
        tester,
        harness.container,
        RecipeDetailPage(recipe: recipe),
      );

      expect(find.text('Egg'), findsWidgets);
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      final checklist = find.byType(CheckboxListTile);
      expect(checklist, findsNWidgets(2));
      await tester.tap(checklist.at(0));
      await tester.pump();
      await tester.tap(checklist.at(1));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      final deductionField = find.byType(TextField).last;
      await tester.enterText(deductionField, '99');
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.enterText(deductionField, '2');
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      expect(harness.container.read(pantryProvider).single.quantity, 8);
      expect(harness.container.read(cookingHistoryProvider), hasLength(1));

      await tester.tap(find.byType(SnackBarAction));
      await tester.pumpAndSettle();

      expect(harness.container.read(pantryProvider).single.quantity, 10);
      expect(
        harness.container
            .read(cookingHistoryProvider)
            .single
            .reversedByTransactionId,
        isNotNull,
      );
    });

    testWidgets('recipe completion without a deductible lot is non-mutating', (
      tester,
    ) async {
      _useLargeSurface(tester);
      final harness = await _Harness.create(
        pantry: const <Ingredient>[],
        now: now,
      );
      addTearDown(harness.dispose);

      await _pumpPage(
        tester,
        harness.container,
        RecipeDetailPage(recipe: _recipe()),
      );

      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      for (final checkbox
          in find.byType(CheckboxListTile).evaluate().toList()) {
        await tester.tap(find.byWidget(checkbox.widget));
        await tester.pump();
      }
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      expect(harness.container.read(pantryProvider), isEmpty);
    });

    testWidgets('history edit and cancel update pantry atomically', (
      tester,
    ) async {
      _useLargeSurface(tester);
      const transactionId = '10000000-0000-4000-8000-000000000001';
      final ingredient = _ingredient(
        id: 'egg-lot',
        name: 'Egg',
        quantity: 6,
        unit: 'piece',
        now: now,
      );
      final history = CookingHistoryEntry(
        originatingTransactionId: transactionId,
        id: transactionId,
        recipeId: 'omelette',
        recipeName: 'Omelette',
        servings: 2,
        changes: const <CookingHistoryChange>[
          CookingHistoryChange(
            ingredientId: 'egg-lot',
            ingredientName: 'Egg',
            unit: 'piece',
            beforeQuantity: 10,
            originalAfterQuantity: 6,
            afterQuantity: 6,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        status: CookingHistoryStatus.completed,
      );
      final harness = await _Harness.create(
        pantry: <Ingredient>[ingredient],
        history: <CookingHistoryEntry>[history],
        now: now,
      );
      addTearDown(harness.dispose);

      await _pumpPage(tester, harness.container, const CookingHistoryPage());
      expect(find.text('Omelette'), findsOneWidget);

      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '20');
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '2');
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
      expect(harness.container.read(pantryProvider).single.quantity, 8);
      expect(
        harness.container.read(cookingHistoryProvider).single.status,
        CookingHistoryStatus.adjusted,
      );

      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      expect(harness.container.read(pantryProvider).single.quantity, 10);
      expect(
        harness.container.read(cookingHistoryProvider).single.status,
        CookingHistoryStatus.cancelled,
      );
    });

    testWidgets('pantry controls drive filtering and durable mutations', (
      tester,
    ) async {
      _useLargeSurface(tester);
      final favoriteCatalog = allFoodCatalogItems.first;
      final pantry = <Ingredient>[
        _ingredient(
          id: 'expired',
          name: 'Old Milk',
          quantity: 1,
          unit: 'bottle',
          now: now,
          expiryDate: now.subtract(const Duration(days: 1)),
        ),
        _ingredient(
          id: 'soon',
          name: favoriteCatalog.item.name,
          quantity: 3,
          unit: 'piece',
          now: now,
          expiryDate: now.add(const Duration(days: 2)),
          isFavorite: true,
        ),
        _ingredient(
          id: 'safe',
          name: 'Rice',
          quantity: 2.5,
          unit: 'kg',
          now: now,
          expiryDate: now.add(const Duration(days: 30)),
        ),
      ];
      final harness = await _Harness.create(
        pantry: pantry,
        favorites: <String>{favoriteCatalog.item.name},
        now: now,
      );
      addTearDown(harness.dispose);

      await _pumpPage(tester, harness.container, const PantryPage());
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.sort_rounded), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Rice');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.filter_alt_off_outlined));
      await tester.pumpAndSettle();

      harness.container
          .read(pantryFilterProvider.notifier)
          .setSortOption(PantrySortOption.nameAscending);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.star_border_rounded).first);
      await tester.pumpAndSettle();
      expect(
        harness.container
            .read(pantryProvider)
            .firstWhere((item) => item.id == 'expired')
            .isFavorite,
        isTrue,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();

      await harness.container
          .read(pantryProvider.notifier)
          .removeIngredient('safe');
      await tester.pumpAndSettle();
      expect(harness.container.read(pantryProvider), hasLength(2));
    });

    testWidgets('home and recipe recommendation pages render rich states', (
      tester,
    ) async {
      _useLargeSurface(tester);
      var openedPantry = false;
      final pantry = <Ingredient>[
        _ingredient(
          id: 'expired',
          name: 'Old Milk',
          quantity: 1,
          unit: 'bottle',
          now: now,
          expiryDate: now.subtract(const Duration(days: 1)),
        ),
        _ingredient(
          id: 'soon',
          name: 'Egg',
          quantity: 10,
          unit: 'piece',
          now: now,
          expiryDate: now.add(const Duration(days: 2)),
        ),
        _ingredient(
          id: 'safe',
          name: 'Rice',
          quantity: 3,
          unit: 'kg',
          now: now,
          expiryDate: now.add(const Duration(days: 20)),
        ),
      ];
      final recipe = _recipe();
      final match = RecipeMatch(
        recipe: recipe,
        matchedIngredients: recipe.ingredients,
        missingIngredients: const <RecipeIngredient>[],
        score: 1,
      );
      const hero = HeroIngredientOption(
        key: 'egg',
        name: 'Egg',
        emoji: 'E',
        recipeCount: 8,
        readyCount: 3,
        bestScorePercent: 100,
        daysUntilExpiry: 2,
      );
      final recommendation = SmartRecommendation(
        hero: hero,
        heroOptions: const <HeroIngredientOption>[
          hero,
          HeroIngredientOption(
            key: 'rice',
            name: 'Rice',
            emoji: 'R',
            recipeCount: 4,
          ),
        ],
        primaryMatches: <RecipeMatch>[match],
        moreMatches: <RecipeMatch>[match],
        totalHeroRecipes: 8,
        pageIndex: 0,
        pageCount: 2,
        heroReason: 'Expires soon',
      );
      final harness = await _Harness.create(
        pantry: pantry,
        now: now,
        recommendation: recommendation,
      );
      addTearDown(harness.dispose);

      await _pumpPage(
        tester,
        harness.container,
        HomePage(onOpenPantry: () => openedPantry = true),
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton).first);
      expect(openedPantry, isTrue);

      await _pumpPage(tester, harness.container, const RecipePage());
      expect(find.textContaining('Egg'), findsWidgets);
      expect(find.byType(ExpansionTile), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.casino_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      final automaticSelection = find.byType(ListTile).last;
      await tester.ensureVisible(automaticSelection);
      await tester.tap(automaticSelection);
      await tester.pumpAndSettle();
    });
  });
}

class _Harness {
  _Harness(this.container);

  final ProviderContainer container;

  static Future<_Harness> create({
    required List<Ingredient> pantry,
    required DateTime now,
    List<CookingHistoryEntry> history = const <CookingHistoryEntry>[],
    Set<String> favorites = const <String>{},
    SmartRecommendation? recommendation,
  }) async {
    final store = InMemoryInventoryStore(
      legacyPantry: pantry,
      legacyHistory: history,
    );
    final clock = FixedAppClock(now);
    final repository = HiveInventoryCommitRepository(
      store: store,
      clock: clock,
    );
    await repository.recoverPendingTransactions();
    final pantryRepository = _MemoryPantryRepository(
      pantry,
      favorites: favorites,
    );
    final container = ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(pantryRepository),
        inventoryCommitRepositoryProvider.overrideWithValue(repository),
        appClockProvider.overrideWithValue(clock),
        transactionIdGeneratorProvider.overrideWithValue(
          SequenceTransactionIdGenerator(
            List<String>.generate(
              20,
              (index) =>
                  '20000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
            ),
          ),
        ),
        if (recommendation != null)
          smartRecommendationProvider.overrideWithValue(
            AsyncValue<SmartRecommendation>.data(recommendation),
          ),
      ],
    );
    container
        .read(cookingHistoryProvider.notifier)
        .replaceFromCommittedSnapshot(history);
    return _Harness(container);
  }

  void dispose() => container.dispose();
}

class _MemoryPantryRepository implements PantryRepository {
  _MemoryPantryRepository(
    List<Ingredient> ingredients, {
    Set<String> favorites = const <String>{},
  }) : _ingredients = List<Ingredient>.of(ingredients),
       _favorites = Set<String>.of(favorites);

  final List<Ingredient> _ingredients;
  Set<String> _favorites;

  @override
  List<Ingredient> getIngredients() => List<Ingredient>.of(_ingredients);

  @override
  Set<String> getFavoriteIngredientNames() => Set<String>.of(_favorites);

  @override
  Future<void> saveFavoriteIngredientNames(Set<String> names) async {
    _favorites = Set<String>.of(names);
  }
}

Ingredient _ingredient({
  required String id,
  required String name,
  required double quantity,
  required String unit,
  required DateTime now,
  DateTime? expiryDate,
  bool isFavorite = false,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: 'Test',
    emoji: 'T',
    quantity: quantity,
    unit: unit,
    expiryDate: expiryDate,
    createdAt: now.subtract(const Duration(days: 10)),
    updatedAt: now,
    isFavorite: isFavorite,
  );
}

Recipe _recipe() {
  return const Recipe(
    id: 'omelette',
    name: 'Omelette',
    category: 'Breakfast',
    description: 'A complete test recipe.',
    emoji: 'O',
    difficulty: 'medium',
    cookTimeMinutes: 12,
    servings: 2,
    tags: <String>['quick', 'protein'],
    cookingMethods: <String>['pan'],
    heroIngredientId: 'egg',
    heroIngredientName: 'Egg',
    popularity: 10,
    sourceUrl: 'https://example.invalid/omelette',
    ingredients: <RecipeIngredient>[
      RecipeIngredient(id: 'egg', name: 'Egg', quantity: 2, unit: 'piece'),
    ],
    steps: <String>['Beat eggs', 'Cook eggs'],
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  ProviderContainer container,
  Widget page,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 0.8;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
