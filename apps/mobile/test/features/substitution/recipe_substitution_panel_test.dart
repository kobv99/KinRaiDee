import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/canonical_ingredient_providers.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient.dart';
import 'package:mobile/core/domain/ingredients/canonical_ingredient_registry.dart';
import 'package:mobile/features/recipe/domain/entities/recipe.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_ingredient.dart';
import 'package:mobile/features/recipe/domain/entities/recipe_readiness.dart';
import 'package:mobile/features/substitution/domain/entities/ingredient_substitution.dart';
import 'package:mobile/features/substitution/presentation/providers/substitution_provider.dart';
import 'package:mobile/features/substitution/presentation/widgets/recipe_substitution_panel.dart';

class _TestRecommendationGroupsNotifier
    extends Notifier<Map<String, List<IngredientSubstitutionRecommendation>>> {
  @override
  Map<String, List<IngredientSubstitutionRecommendation>> build() =>
      _recommendationGroups();

  void replace(
    Map<String, List<IngredientSubstitutionRecommendation>> recommendations,
  ) {
    state = recommendations;
  }
}

final _testRecommendationGroupsProvider =
    NotifierProvider<
      _TestRecommendationGroupsNotifier,
      Map<String, List<IngredientSubstitutionRecommendation>>
    >(_TestRecommendationGroupsNotifier.new);

void main() {
  testWidgets('recommendations stay compact and never gate cooking', (
    tester,
  ) async {
    final readiness = _readiness();
    final container = _container(readiness);
    addTearDown(container.dispose);
    var cookingStarted = false;

    await _pumpPanel(
      tester,
      container: container,
      readiness: readiness,
      onStartCooking: () => cookingStarted = true,
    );

    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-collapsed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-panel')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('recipe-substitution-collapsed')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-panel')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('recipe-substitution-ignore')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-collapsed')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('start-cooking')));
    expect(cookingStarted, isTrue);
  });

  testWidgets('hidden state persists until the recommendation changes', (
    tester,
  ) async {
    final readiness = _readiness();
    final container = _container(readiness);
    addTearDown(container.dispose);

    await _pumpPanel(
      tester,
      container: container,
      readiness: readiness,
      onStartCooking: () {},
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('recipe-substitution-hide-collapsed')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-reopen-chip')),
      findsOneWidget,
    );

    await _pumpPanel(
      tester,
      container: container,
      readiness: readiness,
      onStartCooking: () {},
    );
    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-reopen-chip')),
      findsOneWidget,
    );

    container
        .read(_testRecommendationGroupsProvider.notifier)
        .replace(_recommendationGroups(firstAvailable: false));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-reopen-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-collapsed')),
      findsOneWidget,
    );

    container
        .read(_testRecommendationGroupsProvider.notifier)
        .replace(_recommendationGroups());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-reopen-chip')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('recipe-substitution-collapsed')),
      findsOneWidget,
    );
  });

  testWidgets('accepting remains optional and records only the user choice', (
    tester,
  ) async {
    final readiness = _readiness();
    final container = _container(readiness);
    addTearDown(container.dispose);
    var cookingStarted = false;

    await _pumpPanel(
      tester,
      container: container,
      readiness: readiness,
      onStartCooking: () => cookingStarted = true,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('recipe-substitution-collapsed')),
    );
    await tester.pumpAndSettle();

    final accept = find.byKey(
      const ValueKey<String>('accept-substitution-fish_sauce-soy_sauce'),
    );
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await tester.pump();

    expect(
      container.read(acceptedSubstitutionsProvider),
      containsPair('recipe::fish_sauce', 'soy_sauce'),
    );
    expect(find.text('ใช้ตัวเลือกนี้แล้ว'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('start-cooking')));
    expect(cookingStarted, isTrue);
  });
}

ProviderContainer _container(RecipeReadiness readiness) {
  final request = RecipeSubstitutionRequest(
    recipeId: readiness.recipe.id,
    candidates: readiness.substitutionCandidates,
    recipeSupportsSubstitutions: readiness.recipe.supportsSubstitutions,
  );
  return ProviderContainer(
    overrides: [
      canonicalIngredientRegistryProvider.overrideWithValue(
        CanonicalIngredientRegistry(
          ingredients: [
            _canonical('fish_sauce', 'น้ำปลา'),
            _canonical('soy_sauce', 'ซีอิ๊วขาว'),
            _canonical('salt', 'เกลือ'),
          ],
        ),
      ),
      recipeSubstitutionsProvider(request).overrideWith(
        (ref) async => ref.watch(_testRecommendationGroupsProvider),
      ),
    ],
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required ProviderContainer container,
  required RecipeReadiness readiness,
  required VoidCallback onStartCooking,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: RecipeSubstitutionPanel(
                  recipeId: readiness.recipe.id,
                  readiness: readiness,
                ),
              ),
              Expanded(
                child: Center(
                  child: FilledButton(
                    key: const ValueKey<String>('start-cooking'),
                    onPressed: onStartCooking,
                    child: const Text('เริ่มทำอาหาร'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RecipeReadiness _readiness() {
  const ingredient = RecipeIngredient(
    id: 'fish_sauce',
    name: 'น้ำปลา',
    quantity: 1,
    unit: 'ช้อนโต๊ะ',
    role: RecipeIngredientRole.secondary,
  );
  const recipe = Recipe(
    id: 'recipe',
    name: 'สูตรทดสอบ',
    category: 'test',
    ingredients: [ingredient],
    steps: ['ทำอาหาร'],
    supportsSubstitutions: true,
  );
  return RecipeReadiness(
    recipe: recipe,
    servings: 1,
    score: 0,
    ingredients: const [
      RecipeIngredientReadiness(
        ingredient: ingredient,
        canonicalIngredientId: 'fish_sauce',
        requiredQuantity: 1,
        availableQuantity: 0,
        shortageQuantity: 1,
        availabilityRatio: 0,
        weight: 1,
        status: RecipeIngredientReadinessStatus.missing,
      ),
    ],
  );
}

Map<String, List<IngredientSubstitutionRecommendation>> _recommendationGroups({
  bool firstAvailable = true,
}) {
  return {
    'fish_sauce': [
      IngredientSubstitutionRecommendation(
        substitution: _substitution('soy_sauce'),
        isAvailableInPantry: firstAvailable,
        compatibilityScore: 0.9,
        reason: 'รสเค็มใกล้เคียงและมีอยู่ใน Pantry',
      ),
      IngredientSubstitutionRecommendation(
        substitution: _substitution('salt'),
        isAvailableInPantry: false,
        compatibilityScore: 0.6,
        reason: 'ใช้เพิ่มความเค็มได้ แต่กลิ่นและรสจะต่างจากน้ำปลา',
      ),
    ],
  };
}

IngredientSubstitution _substitution(String substituteIngredientId) {
  return IngredientSubstitution(
    id: 'fish-sauce-$substituteIngredientId',
    originalIngredientId: 'fish_sauce',
    substituteIngredientId: substituteIngredientId,
    confidence: 0.8,
    flavorSimilarity: 0.8,
    textureSimilarity: 1,
    cookingMethodCompatibility: 1,
    suitableDishes: const ['test'],
    unsuitableDishes: const [],
    category: 'seasoning',
    notes: '',
    flavorDifference: '',
    textureDifference: '',
    limitations: '',
  );
}

CanonicalIngredient _canonical(String id, String thaiName) {
  return CanonicalIngredient(
    id: id,
    canonicalName: id,
    localizedNames: {'th': thaiName},
    aliases: const [],
    searchKeywords: const [],
    category: 'seasoning',
    defaultStorageType: IngredientStorageType.pantry,
    defaultPurchaseUnitId: 'tablespoon',
    defaultInventoryUnitId: 'tablespoon',
  );
}
