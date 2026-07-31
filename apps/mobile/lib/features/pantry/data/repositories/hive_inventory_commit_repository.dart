import '../../../../core/time/app_clock.dart';
import '../../../shopping/domain/entities/shopping_item.dart';
import '../../../shopping/domain/entities/shopping_item_status.dart';
import '../../../shopping/domain/entities/shopping_purchase.dart';
import '../../domain/models/cooking_history_entry.dart';
import '../../domain/models/inventory_state_envelope.dart';
import '../../domain/models/inventory_transaction_record.dart';
import '../../domain/repositories/inventory_commit_repository.dart';
import '../storage/hive_inventory_store.dart';
import '../storage/inventory_store.dart';

class HiveInventoryCommitRepository implements InventoryCommitRepository {
  HiveInventoryCommitRepository({
    InventoryStore? store,
    AppClock clock = systemAppClock,
    InventoryCommitObserver observer = const NoopInventoryCommitObserver(),
  }) : _store = store ?? const HiveInventoryStore(),
       // ignore: prefer_initializing_formals
       _clock = clock,
       // ignore: prefer_initializing_formals
       _observer = observer;

  static const double quantityTolerance = 0.000001;

  final InventoryStore _store;
  final AppClock _clock;
  final InventoryCommitObserver _observer;

  @override
  Future<InventoryCommitResult> commit(InventoryCommit commit) async {
    InventoryStateEnvelope current;
    Map<String, InventoryTransactionRecord> journal;
    try {
      current = await _loadOrMigrateEnvelope();
      journal = await _loadJournalMap();
    } on Object {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.recoveryRequired,
        code: 'inventory_load_failed',
        transactionId: commit.transactionId,
      );
    }

    if (journal.values.any(
      (record) => record.state == InventoryTransactionState.recoveryRequired,
    )) {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.recoveryRequired,
        code: 'recovery_required',
        snapshot: current,
        transactionId: commit.transactionId,
      );
    }

    final existing = journal[commit.transactionId];
    if (existing != null) {
      return _handleExisting(commit, existing, current);
    }

    final structuralError = _validateCommitStructure(commit);
    if (structuralError != null) {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.validationFailure,
        code: structuralError,
        snapshot: current,
        transactionId: commit.transactionId,
      );
    }

    var record = InventoryTransactionRecord(
      transactionId: commit.transactionId,
      kind: commit.kind,
      state: InventoryTransactionState.created,
      baseRevision: commit.before.revision,
      targetRevision: commit.after.revision,
      createdAt: commit.createdAt,
      updatedAt: _clock.now(),
      commandChecksum: commit.commandChecksum,
      beforeChecksum: commit.before.checksum,
      afterChecksum: commit.after.checksum,
      beforeEnvelope: commit.before,
      afterEnvelope: commit.after,
    );

    try {
      await _saveRecord(journal, record);
      await _notify(InventoryCommitStage.created, record);
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.validating,
      );

      final validationError = _validateAgainstCurrent(commit, current);
      if (validationError != null) {
        final outcome = validationError == 'stale_inventory_revision'
            ? InventoryCommitOutcome.conflict
            : InventoryCommitOutcome.validationFailure;
        await _rollBack(
          journal,
          record,
          errorCode: validationError,
          envelope: current,
        );
        return InventoryCommitResult(
          outcome: outcome,
          code: validationError,
          snapshot: current,
          transactionId: commit.transactionId,
        );
      }

      record = await _transition(
        journal,
        record,
        InventoryTransactionState.prepared,
      );
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.committing,
      );

      await _store.writeEnvelope(commit.after.toJson());
      await _notify(InventoryCommitStage.envelopeWritten, record);
      final verified = await _readAndValidateEnvelope();
      if (!_matchesTarget(verified, record)) {
        throw const FormatException('Committed envelope verification failed.');
      }

      record = await _transition(
        journal,
        record,
        InventoryTransactionState.committed,
      );
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.committed,
        code: 'committed',
        snapshot: verified,
        transactionId: commit.transactionId,
      );
    } on InventoryProcessInterruption {
      rethrow;
    } on Object {
      return _recoverFailedCommit(commit, journal);
    }
  }

  @override
  Future<void> complete(String transactionId) async {
    final journal = await _loadJournalMap();
    var record = journal[transactionId];
    if (record == null) {
      throw StateError('Unknown inventory transaction: $transactionId');
    }
    if (record.state == InventoryTransactionState.completed) {
      return;
    }
    if (record.state == InventoryTransactionState.committed) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.completing,
      );
    }
    if (record.state == InventoryTransactionState.completing) {
      await _transition(journal, record, InventoryTransactionState.completed);
      return;
    }
    throw StateError(
      'Cannot complete inventory transaction from ${record.state.name}.',
    );
  }

  @override
  Future<List<InventoryTransactionRecord>> loadJournal() async {
    final journal = await _loadJournalMap();
    final records = journal.values.toList()..sort(_compareRecords);
    return List<InventoryTransactionRecord>.unmodifiable(records);
  }

  @override
  Future<InventoryStateEnvelope> loadConsistentSnapshot() {
    return _loadOrMigrateEnvelope();
  }

  @override
  Future<InventoryRecoveryResult> recoverPendingTransactions() async {
    InventoryStateEnvelope envelope;
    Map<String, InventoryTransactionRecord> journal;
    try {
      envelope = await _loadOrMigrateEnvelope();
      journal = await _loadJournalMap();
    } on Object {
      final fallback = InventoryStateEnvelope.initial(createdAt: _clock.now());
      return InventoryRecoveryResult(
        outcome: InventoryRecoveryOutcome.recoveryRequired,
        snapshot: fallback,
        code: 'inventory_recovery_load_failed',
      );
    }

    var recoveredAny = false;
    final pending =
        journal.values
            .where(
              (record) => !isTerminalInventoryTransactionState(record.state),
            )
            .toList()
          ..sort(_compareRecords);

    for (var record in pending) {
      recoveredAny = true;
      if (record.state == InventoryTransactionState.recoveryRequired) {
        return _blocked(envelope, record, 'recovery_required');
      }

      if (record.state == InventoryTransactionState.created ||
          record.state == InventoryTransactionState.validating) {
        if (!_matchesBase(envelope, record)) {
          record = await _moveToRecoveryRequired(
            journal,
            record,
            code: 'base_state_mismatch',
          );
          return _blocked(envelope, record, 'base_state_mismatch');
        }
        await _rollBack(
          journal,
          record,
          errorCode: 'interrupted_before_prepare',
          envelope: envelope,
        );
        continue;
      }

      if (record.state == InventoryTransactionState.prepared ||
          record.state == InventoryTransactionState.committing) {
        if (_matchesTarget(envelope, record)) {
          record = await _advanceToCommitted(journal, record);
          await _finishRecoveredCommit(journal, record);
          continue;
        }
        if (_matchesBase(envelope, record) ||
            await _restoreBeforeEnvelope(record)) {
          envelope = record.beforeEnvelope!;
          await _rollBack(
            journal,
            record,
            errorCode: 'interrupted_commit_rolled_back',
            envelope: envelope,
          );
          continue;
        }
        record = await _moveToRecoveryRequired(
          journal,
          record,
          code: 'unknown_commit_state',
        );
        return _blocked(envelope, record, 'unknown_commit_state');
      }

      if (record.state == InventoryTransactionState.failed ||
          record.state == InventoryTransactionState.rollingBack) {
        if (!_matchesBase(envelope, record) &&
            !await _restoreBeforeEnvelope(record)) {
          record = await _moveToRecoveryRequired(
            journal,
            record,
            code: 'rollback_verification_failed',
          );
          return _blocked(envelope, record, 'rollback_verification_failed');
        }
        envelope = record.beforeEnvelope!;
        await _rollBack(
          journal,
          record,
          errorCode: record.errorCode ?? 'recovered_rollback',
          envelope: envelope,
        );
        continue;
      }

      if (record.state == InventoryTransactionState.committed ||
          record.state == InventoryTransactionState.completing) {
        if (!_matchesTarget(envelope, record)) {
          return _blocked(envelope, record, 'committed_envelope_mismatch');
        }
        await _finishRecoveredCommit(journal, record);
      }
    }

    try {
      _validateEnvelope(envelope);
      _validateJournalInvariants(journal.values, envelope);
    } on Object {
      return InventoryRecoveryResult(
        outcome: InventoryRecoveryOutcome.recoveryRequired,
        snapshot: envelope,
        code: 'global_invariant_failed',
      );
    }

    return InventoryRecoveryResult(
      outcome: recoveredAny
          ? InventoryRecoveryOutcome.recovered
          : InventoryRecoveryOutcome.noWork,
      snapshot: envelope,
    );
  }

  Future<InventoryCommitResult> _handleExisting(
    InventoryCommit commit,
    InventoryTransactionRecord existing,
    InventoryStateEnvelope current,
  ) async {
    if (existing.commandChecksum != commit.commandChecksum ||
        existing.kind != commit.kind ||
        existing.baseRevision != commit.before.revision ||
        existing.targetRevision != commit.after.revision) {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.recoveryRequired,
        code: 'transaction_identity_conflict',
        snapshot: current,
        transactionId: commit.transactionId,
      );
    }

    if (existing.state == InventoryTransactionState.completed ||
        existing.state == InventoryTransactionState.committed ||
        existing.state == InventoryTransactionState.completing) {
      if (!_matchesTarget(current, existing)) {
        return InventoryCommitResult(
          outcome: InventoryCommitOutcome.recoveryRequired,
          code: 'committed_envelope_mismatch',
          snapshot: current,
          transactionId: commit.transactionId,
        );
      }
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.alreadyCommitted,
        code: 'already_committed',
        snapshot: current,
        transactionId: commit.transactionId,
      );
    }

    if (existing.state == InventoryTransactionState.rolledBack) {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.rolledBack,
        code: existing.errorCode ?? 'already_rolled_back',
        snapshot: current,
        transactionId: commit.transactionId,
      );
    }

    final recovery = await recoverPendingTransactions();
    if (!recovery.allowsMutation) {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.recoveryRequired,
        code: recovery.code ?? 'recovery_required',
        snapshot: recovery.snapshot,
        transactionId: commit.transactionId,
      );
    }
    final refreshed = (await _loadJournalMap())[commit.transactionId];
    if (refreshed?.state == InventoryTransactionState.completed) {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.alreadyCommitted,
        code: 'already_committed',
        snapshot: recovery.snapshot,
        transactionId: commit.transactionId,
      );
    }
    return InventoryCommitResult(
      outcome: InventoryCommitOutcome.rolledBack,
      code: refreshed?.errorCode ?? 'already_rolled_back',
      snapshot: recovery.snapshot,
      transactionId: commit.transactionId,
    );
  }

  Future<InventoryCommitResult> _recoverFailedCommit(
    InventoryCommit commit,
    Map<String, InventoryTransactionRecord> previousJournal,
  ) async {
    try {
      final recovery = await recoverPendingTransactions();
      if (!recovery.allowsMutation) {
        return InventoryCommitResult(
          outcome: InventoryCommitOutcome.recoveryRequired,
          code: recovery.code ?? 'recovery_required',
          snapshot: recovery.snapshot,
          transactionId: commit.transactionId,
        );
      }
      final journal = await _loadJournalMap();
      final record = journal[commit.transactionId];
      if (record?.state == InventoryTransactionState.completed) {
        return InventoryCommitResult(
          outcome: InventoryCommitOutcome.committed,
          code: 'committed_after_recovery',
          snapshot: recovery.snapshot,
          transactionId: commit.transactionId,
        );
      }
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.storageFailure,
        code: record?.errorCode ?? 'commit_storage_failure',
        snapshot: recovery.snapshot,
        transactionId: commit.transactionId,
      );
    } on Object {
      return InventoryCommitResult(
        outcome: InventoryCommitOutcome.recoveryRequired,
        code: 'commit_recovery_failed',
        transactionId: commit.transactionId,
      );
    }
  }

  String? _validateCommitStructure(InventoryCommit commit) {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(commit.transactionId)) {
      return 'invalid_transaction_id';
    }
    if (commit.commandChecksum.isEmpty ||
        !commit.before.hasValidChecksum ||
        !commit.after.hasValidChecksum) {
      return 'invalid_transaction_checksum';
    }
    if (commit.after.revision != commit.before.revision + 1 ||
        commit.after.lastAppliedTransactionId != commit.transactionId) {
      return 'invalid_target_revision';
    }
    try {
      _validateEnvelope(commit.before);
      _validateEnvelope(commit.after);
    } on Object {
      return 'invalid_inventory_envelope';
    }
    return null;
  }

  String? _validateAgainstCurrent(
    InventoryCommit commit,
    InventoryStateEnvelope current,
  ) {
    if (current.revision != commit.before.revision ||
        current.checksum != commit.before.checksum) {
      return 'stale_inventory_revision';
    }
    return null;
  }

  Future<InventoryStateEnvelope> _loadOrMigrateEnvelope() async {
    final raw = await _store.readEnvelope();
    if (raw != null) {
      final envelope = InventoryStateEnvelope.fromJson(raw);
      _validateEnvelope(envelope);
      return envelope;
    }

    final legacyPantry = _store.readLegacyPantry();
    final legacyHistory = _store
        .readLegacyHistory()
        .map(_normalizeLegacyHistory)
        .toList(growable: false);
    final backup = <String, dynamic>{
      'version': 1,
      'createdAt': _clock.now().toIso8601String(),
      'pantry': legacyPantry
          .map((item) => item.toJson())
          .toList(growable: false),
      'history': legacyHistory
          .map((item) => item.toJson())
          .toList(growable: false),
    };
    await _store.writeLegacyBackup(backup);
    final envelope = InventoryStateEnvelope.initial(
      createdAt: _clock.now(),
      pantry: legacyPantry,
      history: legacyHistory,
    );
    await _store.writeEnvelope(envelope.toJson());
    final verified = await _readAndValidateEnvelope();
    if (verified.checksum != envelope.checksum) {
      throw const FormatException('Legacy migration verification failed.');
    }
    return verified;
  }

  CookingHistoryEntry _normalizeLegacyHistory(CookingHistoryEntry entry) {
    if (entry.originatingTransactionId.isNotEmpty) {
      return entry;
    }
    return CookingHistoryEntry(
      schemaVersion: entry.schemaVersion,
      originatingTransactionId: entry.id,
      adjustedByTransactionId: entry.adjustedByTransactionId,
      cancelledByTransactionId: entry.cancelledByTransactionId,
      reversedByTransactionId: entry.reversedByTransactionId,
      id: entry.id,
      recipeId: entry.recipeId,
      recipeName: entry.recipeName,
      servings: entry.servings,
      changes: entry.changes,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      status: entry.status,
    );
  }

  Future<InventoryStateEnvelope> _readAndValidateEnvelope() async {
    final raw = await _store.readEnvelope();
    if (raw == null) {
      throw const FormatException('Inventory envelope is missing.');
    }
    final envelope = InventoryStateEnvelope.fromJson(raw);
    _validateEnvelope(envelope);
    return envelope;
  }

  void _validateEnvelope(InventoryStateEnvelope envelope) {
    if (envelope.envelopeVersion != currentInventoryEnvelopeVersion ||
        envelope.minimumReaderVersion > currentInventoryReaderVersion ||
        envelope.revision < 0 ||
        !envelope.hasValidChecksum) {
      throw const FormatException('Unsupported or corrupt inventory envelope.');
    }
    final pantryIds = <String>{};
    for (final ingredient in envelope.pantry) {
      if (ingredient.id.isEmpty ||
          !pantryIds.add(ingredient.id) ||
          !ingredient.quantity.isFinite ||
          ingredient.quantity < 0) {
        throw const FormatException('Invalid Pantry state in envelope.');
      }
    }
    final historyIds = <String>{};
    for (final entry in envelope.history) {
      if (entry.id.isEmpty || !historyIds.add(entry.id)) {
        throw const FormatException('Invalid History state in envelope.');
      }
    }
    final hasShopping = envelope.capabilities.contains(shoppingStateCapability);
    final hasShoppingEngine = envelope.capabilities.contains(
      shoppingEngineCapability,
    );
    if ((!hasShopping && envelope.shoppingLists.isNotEmpty) ||
        (hasShopping && envelope.minimumReaderVersion < 2) ||
        (hasShoppingEngine && !hasShopping) ||
        (hasShoppingEngine && envelope.minimumReaderVersion < 3)) {
      throw const FormatException('Invalid Shopping capability in envelope.');
    }
    final shoppingListIds = <String>{};
    for (final list in envelope.shoppingLists) {
      if (list.metadataVersion != 1 ||
          list.id.isEmpty ||
          !shoppingListIds.add(list.id) ||
          list.name.trim().isEmpty ||
          list.revision < 0 ||
          list.updatedAt.toUtc().isBefore(list.createdAt.toUtc())) {
        throw const FormatException('Invalid Shopping list in envelope.');
      }
      final itemIds = <String>{};
      final activeIdentities = <String>{};
      final legacyIdentities = <String>{};
      for (final item in list.items) {
        final supportedItemVersion = hasShoppingEngine
            ? item.metadataVersion == currentShoppingItemVersion
            : item.metadataVersion == 1;
        final sourceIsValid =
            item.source.name == 'manual' || item.sourceReferenceIds.isNotEmpty;
        final purchase = item.purchase;
        final purchaseIsValid = item.status == ShoppingItemStatus.active
            ? purchase == null
            : purchase != null &&
                  purchase.metadataVersion == currentShoppingPurchaseVersion &&
                  purchase.transactionId.isNotEmpty &&
                  purchase.pantryLotId.isNotEmpty &&
                  purchase.pantryUnitId.isNotEmpty &&
                  purchase.beforeQuantity.isFinite &&
                  purchase.afterQuantity.isFinite &&
                  purchase.beforeQuantity >= 0 &&
                  purchase.afterQuantity > purchase.beforeQuantity;
        final activeIdentityIsUnique =
            item.status != ShoppingItemStatus.active ||
            (hasShoppingEngine
                ? activeIdentities.add(item.canonicalIngredientId)
                : legacyIdentities.add(
                    '${item.canonicalIngredientId}::${item.unitId}',
                  ));
        if (!supportedItemVersion ||
            item.id.isEmpty ||
            !itemIds.add(item.id) ||
            item.canonicalIngredientId.isEmpty ||
            item.unitId.isEmpty ||
            item.displayName.trim().isEmpty ||
            !item.quantity.isFinite ||
            item.quantity <= 0 ||
            item.updatedAt.toUtc().isBefore(item.createdAt.toUtc()) ||
            !sourceIsValid ||
            !purchaseIsValid ||
            !activeIdentityIsUnique) {
          throw const FormatException('Invalid Shopping item in envelope.');
        }
      }
    }
  }

  Future<Map<String, InventoryTransactionRecord>> _loadJournalMap() async {
    final raw = await _store.readJournal();
    if (raw == null) {
      return <String, InventoryTransactionRecord>{};
    }
    if (_parseInt(raw['journalVersion'], fallback: -1) != 1) {
      throw const FormatException('Unsupported inventory journal version.');
    }
    final rawRecords = raw['records'];
    if (rawRecords is! List) {
      throw const FormatException('Inventory journal records are invalid.');
    }
    final result = <String, InventoryTransactionRecord>{};
    for (final item in rawRecords.whereType<Map>()) {
      final record = InventoryTransactionRecord.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (record.transactionVersion != currentInventoryTransactionVersion ||
          record.transactionId.isEmpty ||
          result.containsKey(record.transactionId)) {
        throw const FormatException('Inventory journal invariant failed.');
      }
      result[record.transactionId] = record;
    }
    return result;
  }

  Future<void> _persistJournal(
    Map<String, InventoryTransactionRecord> journal,
  ) {
    final records = journal.values.toList()..sort(_compareRecords);
    return _store.writeJournal(<String, dynamic>{
      'journalVersion': 1,
      'records': records
          .map((record) => record.toJson())
          .toList(growable: false),
    });
  }

  Future<void> _saveRecord(
    Map<String, InventoryTransactionRecord> journal,
    InventoryTransactionRecord record,
  ) async {
    journal[record.transactionId] = record;
    await _persistJournal(journal);
  }

  Future<InventoryTransactionRecord> _transition(
    Map<String, InventoryTransactionRecord> journal,
    InventoryTransactionRecord record,
    InventoryTransactionState state, {
    String? errorCode,
  }) async {
    final updated = record.transitionTo(
      state,
      at: _clock.now(),
      errorCode: errorCode,
    );
    await _saveRecord(journal, updated);
    await _notify(_stageForState(state), updated);
    return updated;
  }

  Future<void> _notify(
    InventoryCommitStage stage,
    InventoryTransactionRecord record,
  ) {
    return _observer.reached(stage, record);
  }

  Future<InventoryTransactionRecord> _advanceToCommitted(
    Map<String, InventoryTransactionRecord> journal,
    InventoryTransactionRecord record,
  ) async {
    if (record.state == InventoryTransactionState.prepared) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.committing,
      );
    }
    if (record.state == InventoryTransactionState.committing) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.committed,
      );
    }
    return record;
  }

  Future<void> _finishRecoveredCommit(
    Map<String, InventoryTransactionRecord> journal,
    InventoryTransactionRecord record,
  ) async {
    if (record.state == InventoryTransactionState.committed) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.completing,
      );
    }
    if (record.state == InventoryTransactionState.completing) {
      await _transition(journal, record, InventoryTransactionState.completed);
    }
  }

  Future<InventoryTransactionRecord> _rollBack(
    Map<String, InventoryTransactionRecord> journal,
    InventoryTransactionRecord record, {
    required String errorCode,
    required InventoryStateEnvelope envelope,
  }) async {
    if (record.state == InventoryTransactionState.created ||
        record.state == InventoryTransactionState.validating ||
        record.state == InventoryTransactionState.prepared ||
        record.state == InventoryTransactionState.committing) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.failed,
        errorCode: errorCode,
      );
    }
    if (record.state == InventoryTransactionState.failed) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.rollingBack,
        errorCode: errorCode,
      );
    }
    if (record.state == InventoryTransactionState.rollingBack) {
      if (!_matchesBase(envelope, record)) {
        if (!await _restoreBeforeEnvelope(record)) {
          return _transition(
            journal,
            record,
            InventoryTransactionState.recoveryRequired,
            errorCode: 'rollback_verification_failed',
          );
        }
      }
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.rolledBack,
        errorCode: errorCode,
      );
    }
    return record;
  }

  Future<InventoryTransactionRecord> _moveToRecoveryRequired(
    Map<String, InventoryTransactionRecord> journal,
    InventoryTransactionRecord record, {
    required String code,
  }) async {
    if (record.state == InventoryTransactionState.prepared ||
        record.state == InventoryTransactionState.committing ||
        record.state == InventoryTransactionState.created ||
        record.state == InventoryTransactionState.validating) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.failed,
        errorCode: code,
      );
    }
    if (record.state == InventoryTransactionState.failed) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.rollingBack,
        errorCode: code,
      );
    }
    if (record.state == InventoryTransactionState.rollingBack) {
      record = await _transition(
        journal,
        record,
        InventoryTransactionState.recoveryRequired,
        errorCode: code,
      );
    }
    return record;
  }

  Future<bool> _restoreBeforeEnvelope(InventoryTransactionRecord record) async {
    final before = record.beforeEnvelope;
    if (before == null || !before.hasValidChecksum) {
      return false;
    }
    try {
      await _store.writeEnvelope(before.toJson());
      final verified = await _readAndValidateEnvelope();
      return _matchesBase(verified, record);
    } on Object {
      return false;
    }
  }

  bool _matchesBase(
    InventoryStateEnvelope envelope,
    InventoryTransactionRecord record,
  ) {
    return envelope.revision == record.baseRevision &&
        envelope.checksum == record.beforeChecksum;
  }

  bool _matchesTarget(
    InventoryStateEnvelope envelope,
    InventoryTransactionRecord record,
  ) {
    return envelope.revision == record.targetRevision &&
        envelope.lastAppliedTransactionId == record.transactionId &&
        envelope.checksum == record.afterChecksum;
  }

  void _validateJournalInvariants(
    Iterable<InventoryTransactionRecord> records,
    InventoryStateEnvelope envelope,
  ) {
    final ids = <String>{};
    var previousRevision = -1;
    final ordered = records.toList()..sort(_compareRecords);
    for (final record in ordered) {
      if (!ids.add(record.transactionId) ||
          record.targetRevision != record.baseRevision + 1 ||
          record.baseRevision < previousRevision) {
        throw const FormatException('Journal revision invariant failed.');
      }
      previousRevision = record.baseRevision;
    }
    _validateEnvelope(envelope);
  }

  InventoryRecoveryResult _blocked(
    InventoryStateEnvelope envelope,
    InventoryTransactionRecord record,
    String code,
  ) {
    return InventoryRecoveryResult(
      outcome: InventoryRecoveryOutcome.recoveryRequired,
      snapshot: envelope,
      blockingTransactionId: record.transactionId,
      code: code,
    );
  }
}

InventoryCommitStage _stageForState(InventoryTransactionState state) {
  return switch (state) {
    InventoryTransactionState.created => InventoryCommitStage.created,
    InventoryTransactionState.validating => InventoryCommitStage.validating,
    InventoryTransactionState.prepared => InventoryCommitStage.prepared,
    InventoryTransactionState.committing => InventoryCommitStage.committing,
    InventoryTransactionState.committed => InventoryCommitStage.committed,
    InventoryTransactionState.completing => InventoryCommitStage.completing,
    InventoryTransactionState.completed => InventoryCommitStage.completed,
    InventoryTransactionState.failed => InventoryCommitStage.failed,
    InventoryTransactionState.rollingBack => InventoryCommitStage.rollingBack,
    InventoryTransactionState.rolledBack => InventoryCommitStage.rolledBack,
    InventoryTransactionState.recoveryRequired =>
      InventoryCommitStage.recoveryRequired,
  };
}

int _compareRecords(
  InventoryTransactionRecord first,
  InventoryTransactionRecord second,
) {
  final time = first.createdAt.compareTo(second.createdAt);
  return time != 0 ? time : first.transactionId.compareTo(second.transactionId);
}

int _parseInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
