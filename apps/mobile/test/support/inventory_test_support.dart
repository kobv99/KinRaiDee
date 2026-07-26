import 'dart:convert';

import 'package:mobile/core/models/ingredient.dart';
import 'package:mobile/core/utils/transaction_id_generator.dart';
import 'package:mobile/features/pantry/data/storage/inventory_store.dart';
import 'package:mobile/features/pantry/domain/models/cooking_history_entry.dart';
import 'package:mobile/features/pantry/domain/models/inventory_transaction_record.dart';

class InMemoryInventoryStore implements InventoryStore {
  InMemoryInventoryStore({
    Map<String, dynamic>? envelope,
    Map<String, dynamic>? journal,
    List<Ingredient> legacyPantry = const <Ingredient>[],
    List<CookingHistoryEntry> legacyHistory = const <CookingHistoryEntry>[],
  }) : _envelope = _copy(envelope),
       _journal = _copy(journal),
       _legacyPantry = List<Ingredient>.of(legacyPantry),
       _legacyHistory = List<CookingHistoryEntry>.of(legacyHistory);

  Map<String, dynamic>? _envelope;
  Map<String, dynamic>? _journal;
  Map<String, dynamic>? legacyBackup;
  final List<Ingredient> _legacyPantry;
  final List<CookingHistoryEntry> _legacyHistory;
  bool failEnvelopeWrites = false;
  bool failJournalWrites = false;
  int envelopeWriteCount = 0;
  int journalWriteCount = 0;

  Map<String, dynamic>? get envelope => _copy(_envelope);
  Map<String, dynamic>? get journal => _copy(_journal);

  @override
  Future<Map<String, dynamic>?> readEnvelope() async => _copy(_envelope);

  @override
  Future<Map<String, dynamic>?> readJournal() async => _copy(_journal);

  @override
  List<CookingHistoryEntry> readLegacyHistory() {
    return List<CookingHistoryEntry>.of(_legacyHistory);
  }

  @override
  List<Ingredient> readLegacyPantry() {
    return List<Ingredient>.of(_legacyPantry);
  }

  @override
  Future<void> writeEnvelope(Map<String, dynamic> envelope) async {
    envelopeWriteCount++;
    if (failEnvelopeWrites) {
      throw StateError('Injected envelope write failure.');
    }
    _envelope = _copy(envelope);
  }

  @override
  Future<void> writeJournal(Map<String, dynamic> journal) async {
    journalWriteCount++;
    if (failJournalWrites) {
      throw StateError('Injected journal write failure.');
    }
    _journal = _copy(journal);
  }

  @override
  Future<void> writeLegacyBackup(Map<String, dynamic> backup) async {
    legacyBackup = _copy(backup);
  }
}

class InterruptOnceObserver implements InventoryCommitObserver {
  InterruptOnceObserver(this.stage);

  final InventoryCommitStage stage;
  bool interrupted = false;

  @override
  Future<void> reached(
    InventoryCommitStage current,
    InventoryTransactionRecord record,
  ) async {
    if (!interrupted && current == stage) {
      interrupted = true;
      throw InventoryProcessInterruption(stage);
    }
  }
}

class SequenceTransactionIdGenerator implements TransactionIdGenerator {
  SequenceTransactionIdGenerator([List<String>? values])
    : _values = values ?? _defaultValues;

  final List<String> _values;
  int _index = 0;

  @override
  String generate() {
    if (_index >= _values.length) {
      throw StateError('No test transaction IDs remain.');
    }
    return _values[_index++];
  }
}

const List<String> _defaultValues = <String>[
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000003',
  '00000000-0000-4000-8000-000000000004',
  '00000000-0000-4000-8000-000000000005',
  '00000000-0000-4000-8000-000000000006',
  '00000000-0000-4000-8000-000000000007',
  '00000000-0000-4000-8000-000000000008',
];

Map<String, dynamic>? _copy(Map<String, dynamic>? value) {
  if (value == null) {
    return null;
  }
  return Map<String, dynamic>.from(
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
  );
}
