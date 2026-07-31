import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/shopping/presentation/providers/recommendation_ui_provider.dart';

void main() {
  test('starts neither dismissed nor busy', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(recommendationUiProvider);

    expect(state.dismissed, isFalse);
    expect(state.busyIngredientId, isNull);
  });

  test('dismiss() sets dismissed without disturbing busy state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(recommendationUiProvider.notifier);

    notifier.setBusyIngredient('egg');
    notifier.dismiss();

    final state = container.read(recommendationUiProvider);
    expect(state.dismissed, isTrue);
    expect(state.busyIngredientId, 'egg');
  });

  test('setBusyIngredient() toggles busy state independent of dismissed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(recommendationUiProvider.notifier);

    notifier.setBusyIngredient('egg');
    expect(container.read(recommendationUiProvider).busyIngredientId, 'egg');

    notifier.setBusyIngredient(null);
    expect(container.read(recommendationUiProvider).busyIngredientId, isNull);
  });

  test('reset() clears both dismissed and busy state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(recommendationUiProvider.notifier);

    notifier.setBusyIngredient('egg');
    notifier.dismiss();
    notifier.reset();

    final state = container.read(recommendationUiProvider);
    expect(state.dismissed, isFalse);
    expect(state.busyIngredientId, isNull);
  });

  test(
    'state is shared: dismissing is visible to every consumer of the '
    'provider, which is what lets Pantry and Shopping show one consistent '
    'Recommended Purchases surface instead of two out-of-sync copies',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(recommendationUiProvider.notifier).dismiss();

      expect(container.read(recommendationUiProvider).dismissed, isTrue);
    },
  );
}
