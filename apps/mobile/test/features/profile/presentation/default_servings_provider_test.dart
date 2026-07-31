import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/presentation/providers/default_servings_provider.dart';

void main() {
  test(
    'starts as null (use the recipe base servings) when nothing is saved',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Storage is unavailable in this isolated test, so build() must fail
      // safe to null rather than throw.
      expect(container.read(defaultServingsProvider), isNull);
    },
  );

  test(
    'set updates in-memory state even when persistence is unavailable',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(defaultServingsProvider.notifier).set(4);

      expect(container.read(defaultServingsProvider), 4);
    },
  );

  test('set(null) clears the preference', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(defaultServingsProvider.notifier);
    await notifier.set(4);
    await notifier.set(null);

    expect(container.read(defaultServingsProvider), isNull);
  });
}
