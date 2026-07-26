import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pantry/application/inventory_transaction_providers.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';
import 'package:mobile/features/pantry/domain/models/inventory_state_envelope.dart';
import 'package:mobile/features/pantry/domain/repositories/inventory_commit_repository.dart';
import 'package:mobile/features/pantry/presentation/providers/cooking_history_provider.dart';

void main() {
  test('loads sorted history from the durable startup snapshot', () {
    final older = _entry('older', DateTime.utc(2026, 7, 25));
    final newer = _entry('newer', DateTime.utc(2026, 7, 26));
    final snapshot = InventoryStateEnvelope.initial(
      createdAt: DateTime.utc(2026, 7, 24),
      history: <CookingHistoryEntry>[older, newer],
    );
    final container = ProviderContainer(
      overrides: [
        inventoryStartupRecoveryProvider.overrideWithValue(
          InventoryRecoveryResult(
            outcome: InventoryRecoveryOutcome.recovered,
            snapshot: snapshot,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(cookingHistoryProvider).map((entry) => entry.id).toList(),
      <String>['newer', 'older'],
    );
  });
}

CookingHistoryEntry _entry(String id, DateTime at) {
  return CookingHistoryEntry(
    id: id,
    recipeId: 'recipe-$id',
    recipeName: 'Recipe $id',
    servings: 1,
    changes: const <CookingHistoryChange>[],
    createdAt: at,
    updatedAt: at,
    status: CookingHistoryStatus.completed,
  );
}
