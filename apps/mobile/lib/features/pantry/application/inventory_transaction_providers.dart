import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/canonical_ingredient_providers.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/utils/transaction_id_generator.dart';
import '../data/repositories/hive_inventory_commit_repository.dart';
import '../domain/repositories/inventory_commit_repository.dart';
import 'inventory_transaction_coordinator.dart';

final appClockProvider = Provider<AppClock>((ref) => systemAppClock);

final transactionIdGeneratorProvider = Provider<TransactionIdGenerator>((ref) {
  return SecureTransactionIdGenerator();
});

final inventoryCommitRepositoryProvider = Provider<InventoryCommitRepository>((
  ref,
) {
  return HiveInventoryCommitRepository(clock: ref.watch(appClockProvider));
});

final inventoryStartupRecoveryProvider = Provider<InventoryRecoveryResult?>(
  (ref) => null,
);

final inventoryTransactionCoordinatorProvider =
    Provider<InventoryTransactionCoordinator>((ref) {
      return InventoryTransactionCoordinator(
        repository: ref.watch(inventoryCommitRepositoryProvider),
        clock: ref.watch(appClockProvider),
        transactionIdGenerator: ref.watch(transactionIdGeneratorProvider),
        canonicalIngredientRegistry: ref.watch(
          canonicalIngredientRegistryProvider,
        ),
        unitConversionEngine: ref.watch(unitConversionEngineProvider),
      );
    });
