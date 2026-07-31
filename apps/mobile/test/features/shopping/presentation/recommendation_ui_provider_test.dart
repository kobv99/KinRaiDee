import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/shopping/presentation/providers/recommendation_ui_provider.dart';

void main() {
  test('starts not dismissed and with no busy ingredient', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(recommendationUiProvider);
    expect(state.dismissed, isFalse);
    expect(state.busyIngredientId, isNull);
  });

  test('dismiss is shared across every reader of the provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(recommendationUiProvider.notifier).dismiss();

    expect(container.read(recommendationUiProvider).dismissed, isTrue);
  });

  test('setBusyIngredient tracks the busy id without touching dismissed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(recommendationUiProvider.notifier).dismiss();
    container
        .read(recommendationUiProvider.notifier)
        .setBusyIngredient('egg');

    final state = container.read(recommendationUiProvider);
    expect(state.busyIngredientId, 'egg');
    expect(state.dismissed, isTrue);

    container.read(recommendationUiProvider.notifier).setBusyIngredient(null);
    expect(container.read(recommendationUiProvider).busyIngredientId, isNull);
  });

  test('reset clears both dismissed and busy state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(recommendationUiProvider.notifier);
    notifier.dismiss();
    notifier.setBusyIngredient('egg');

    notifier.reset();

    final state = container.read(recommendationUiProvider);
    expect(state.dismissed, isFalse);
    expect(state.busyIngredientId, isNull);
  });
}
