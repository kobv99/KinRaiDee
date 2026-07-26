import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/models/ingredient.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/cooking_history_entry.dart';
import 'inventory_store.dart';

class HiveInventoryStore implements InventoryStore {
  const HiveInventoryStore();

  static const String envelopeKey = StorageService.inventoryEnvelopeKey;
  static const String journalKey = 'inventory_transaction_journal_v1';
  static const String legacyBackupKey = 'inventory_legacy_backup_v1';

  Box<dynamic> get _box {
    if (!Hive.isBoxOpen(StorageService.pantryBoxName)) {
      throw StateError('Inventory storage has not been initialized.');
    }
    return Hive.box<dynamic>(StorageService.pantryBoxName);
  }

  @override
  Future<Map<String, dynamic>?> readEnvelope() async {
    return _mapOrNull(_box.get(envelopeKey));
  }

  @override
  Future<Map<String, dynamic>?> readJournal() async {
    return _mapOrNull(_box.get(journalKey));
  }

  @override
  List<CookingHistoryEntry> readLegacyHistory() {
    return StorageService.loadCookingHistory();
  }

  @override
  List<Ingredient> readLegacyPantry() {
    return StorageService.loadIngredients();
  }

  @override
  Future<void> writeEnvelope(Map<String, dynamic> envelope) async {
    await _box.put(envelopeKey, envelope);
    await _box.flush();
  }

  @override
  Future<void> writeJournal(Map<String, dynamic> journal) async {
    await _box.put(journalKey, journal);
    await _box.flush();
  }

  @override
  Future<void> writeLegacyBackup(Map<String, dynamic> backup) async {
    await _box.put(legacyBackupKey, backup);
    await _box.flush();
  }
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw const FormatException('Inventory storage value is not a map.');
  }
  return Map<String, dynamic>.from(value);
}
