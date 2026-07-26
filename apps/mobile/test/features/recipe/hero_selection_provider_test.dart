import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recipe/domain/entities/smart_recommendation.dart';
import 'package:mobile/features/recipe/domain/repositories/hero_selection_repository.dart';
import 'package:mobile/features/recipe/presentation/providers/recipe_provider.dart';

void main() {
  test('loads a persisted hero through the repository boundary', () {
    final repository = _FakeHeroSelectionRepository(pinnedKey: 'egg');
    final container = ProviderContainer(
      overrides: [
        heroSelectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(heroSelectionProvider);

    expect(state.mode, HeroSelectionMode.pinned);
    expect(state.key, 'egg');
  });

  test('pin and automatic selection persist through the repository', () async {
    final repository = _FakeHeroSelectionRepository();
    final container = ProviderContainer(
      overrides: [
        heroSelectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(heroSelectionProvider.notifier);

    await notifier.pin('chicken-breast');

    expect(
      container.read(heroSelectionProvider).mode,
      HeroSelectionMode.pinned,
    );
    expect(repository.pinnedKey, 'chicken-breast');

    await notifier.useAutomatic();

    expect(container.read(heroSelectionProvider).isAutomatic, isTrue);
    expect(repository.pinnedKey, isNull);
    expect(repository.clearCount, 1);
  });

  test('session selection clears a durable pin', () async {
    final repository = _FakeHeroSelectionRepository(pinnedKey: 'egg');
    final container = ProviderContainer(
      overrides: [
        heroSelectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(heroSelectionProvider.notifier)
        .selectForSession('pork', reason: '  expires first  ');

    final state = container.read(heroSelectionProvider);
    expect(state.mode, HeroSelectionMode.manual);
    expect(state.key, 'pork');
    expect(state.reason, 'expires first');
    expect(repository.pinnedKey, isNull);
  });
}

class _FakeHeroSelectionRepository implements HeroSelectionRepository {
  _FakeHeroSelectionRepository({this.pinnedKey});

  String? pinnedKey;
  int clearCount = 0;

  @override
  Future<void> clearPinnedIngredientKey() async {
    pinnedKey = null;
    clearCount += 1;
  }

  @override
  String? loadPinnedIngredientKey() => pinnedKey;

  @override
  Future<void> savePinnedIngredientKey(String key) async {
    pinnedKey = key;
  }
}
