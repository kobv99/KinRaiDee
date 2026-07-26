import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers/canonical_ingredient_providers.dart';
import 'core/domain/units/unit_contract.dart';
import 'core/services/storage_service.dart';
import 'features/pantry/application/canonical_ingredient_migration.dart';
import 'features/pantry/application/inventory_transaction_coordinator.dart';
import 'features/pantry/application/inventory_transaction_providers.dart';
import 'features/pantry/data/repositories/hive_inventory_commit_repository.dart';
import 'features/pantry/domain/repositories/inventory_commit_repository.dart';
import 'features/recipe/data/ingredient_catalog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.init();
  final inventoryRepository = HiveInventoryCommitRepository();
  var recovery = await inventoryRepository.recoverPendingTransactions();
  final unitEngine = UnitConversionEngine.standard();
  final registry = await IngredientCatalog(
    unitConversionEngine: unitEngine,
  ).loadRegistry();
  CanonicalIngredientMigrationResult? migration;

  if (recovery.allowsMutation) {
    migration =
        CanonicalIngredientMigration(
          registry: registry,
          unitEngine: unitEngine,
        ).migrate(
          pantry: recovery.snapshot.pantry,
          history: recovery.snapshot.history,
        );
    if (migration.changed) {
      final coordinator = InventoryTransactionCoordinator(
        repository: inventoryRepository,
      );
      final result = await coordinator.migrateCanonicalIngredients(
        pantry: migration.pantry,
        history: migration.history,
        targetSchemaVersion: canonicalIngredientMigrationVersion,
      );
      if (result.isSuccess) {
        final transactionId = result.transaction?.transactionId;
        if (result.outcome == InventoryTransactionOutcome.committed &&
            transactionId != null) {
          await coordinator.completePresentation(transactionId);
        }
        recovery = InventoryRecoveryResult(
          outcome: InventoryRecoveryOutcome.recovered,
          snapshot: result.snapshot,
          code: result.code,
        );
      } else {
        recovery = InventoryRecoveryResult(
          outcome: InventoryRecoveryOutcome.recoveryRequired,
          snapshot: result.snapshot,
          blockingTransactionId: result.transaction?.transactionId,
          code: result.code,
        );
      }
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        inventoryCommitRepositoryProvider.overrideWithValue(
          inventoryRepository,
        ),
        inventoryStartupRecoveryProvider.overrideWithValue(recovery),
        unitConversionEngineProvider.overrideWithValue(unitEngine),
        canonicalIngredientRegistryProvider.overrideWithValue(registry),
        canonicalIngredientMigrationReportProvider.overrideWithValue(migration),
      ],
      child: recovery.allowsMutation
          ? const KinRaiDeeApp()
          : const _InventoryRecoveryRequiredApp(),
    ),
  );
}

class _InventoryRecoveryRequiredApp extends StatelessWidget {
  const _InventoryRecoveryRequiredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Inventory recovery is required. Pantry changes are disabled '
                'to protect your data.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
