import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/storage_service.dart';
import 'features/pantry/application/inventory_transaction_providers.dart';
import 'features/pantry/data/repositories/hive_inventory_commit_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.init();
  final inventoryRepository = HiveInventoryCommitRepository();
  final recovery = await inventoryRepository.recoverPendingTransactions();

  runApp(
    ProviderScope(
      overrides: [
        inventoryCommitRepositoryProvider.overrideWithValue(
          inventoryRepository,
        ),
        inventoryStartupRecoveryProvider.overrideWithValue(recovery),
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
