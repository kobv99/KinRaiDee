import 'inventory_state_envelope.dart';
import 'pantry_quantity_transaction.dart';

const int currentInventoryTransactionVersion = 1;

enum InventoryTransactionState {
  created,
  validating,
  prepared,
  committing,
  committed,
  completing,
  completed,
  failed,
  rollingBack,
  rolledBack,
  recoveryRequired,
}

const Map<InventoryTransactionState, Set<InventoryTransactionState>>
inventoryTransactionTransitions =
    <InventoryTransactionState, Set<InventoryTransactionState>>{
      InventoryTransactionState.created: <InventoryTransactionState>{
        InventoryTransactionState.validating,
        InventoryTransactionState.failed,
      },
      InventoryTransactionState.validating: <InventoryTransactionState>{
        InventoryTransactionState.prepared,
        InventoryTransactionState.failed,
      },
      InventoryTransactionState.prepared: <InventoryTransactionState>{
        InventoryTransactionState.committing,
        InventoryTransactionState.failed,
      },
      InventoryTransactionState.committing: <InventoryTransactionState>{
        InventoryTransactionState.committed,
        InventoryTransactionState.failed,
      },
      InventoryTransactionState.committed: <InventoryTransactionState>{
        InventoryTransactionState.completing,
      },
      InventoryTransactionState.completing: <InventoryTransactionState>{
        InventoryTransactionState.completed,
      },
      InventoryTransactionState.completed: <InventoryTransactionState>{},
      InventoryTransactionState.failed: <InventoryTransactionState>{
        InventoryTransactionState.rollingBack,
      },
      InventoryTransactionState.rollingBack: <InventoryTransactionState>{
        InventoryTransactionState.rolledBack,
        InventoryTransactionState.recoveryRequired,
      },
      InventoryTransactionState.rolledBack: <InventoryTransactionState>{},
      InventoryTransactionState.recoveryRequired: <InventoryTransactionState>{
        InventoryTransactionState.rollingBack,
      },
    };

bool isLegalInventoryTransition(
  InventoryTransactionState from,
  InventoryTransactionState to,
) {
  return inventoryTransactionTransitions[from]?.contains(to) ?? false;
}

bool isTerminalInventoryTransactionState(InventoryTransactionState state) {
  return state == InventoryTransactionState.completed ||
      state == InventoryTransactionState.rolledBack;
}

class InventoryTransactionRecord {
  InventoryTransactionRecord({
    this.transactionVersion = currentInventoryTransactionVersion,
    this.commandVersion = 1,
    required this.transactionId,
    required this.kind,
    required this.state,
    required this.baseRevision,
    required this.targetRevision,
    required this.createdAt,
    required this.updatedAt,
    required this.commandChecksum,
    required this.beforeChecksum,
    required this.afterChecksum,
    this.beforeEnvelope,
    this.afterEnvelope,
    this.errorCode,
  });

  final int transactionVersion;
  final int commandVersion;
  final String transactionId;
  final InventoryTransactionKind kind;
  final InventoryTransactionState state;
  final int baseRevision;
  final int targetRevision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String commandChecksum;
  final String beforeChecksum;
  final String afterChecksum;
  final InventoryStateEnvelope? beforeEnvelope;
  final InventoryStateEnvelope? afterEnvelope;
  final String? errorCode;

  InventoryTransactionRecord transitionTo(
    InventoryTransactionState next, {
    required DateTime at,
    String? errorCode,
  }) {
    if (!isLegalInventoryTransition(state, next)) {
      throw StateError(
        'Illegal inventory transaction transition: ${state.name} -> ${next.name}',
      );
    }
    return copyWith(state: next, updatedAt: at, errorCode: errorCode);
  }

  InventoryTransactionRecord copyWith({
    InventoryTransactionState? state,
    DateTime? updatedAt,
    InventoryStateEnvelope? beforeEnvelope,
    InventoryStateEnvelope? afterEnvelope,
    String? beforeChecksum,
    String? afterChecksum,
    String? errorCode,
  }) {
    return InventoryTransactionRecord(
      transactionVersion: transactionVersion,
      commandVersion: commandVersion,
      transactionId: transactionId,
      kind: kind,
      state: state ?? this.state,
      baseRevision: baseRevision,
      targetRevision: targetRevision,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      commandChecksum: commandChecksum,
      beforeChecksum: beforeChecksum ?? this.beforeChecksum,
      afterChecksum: afterChecksum ?? this.afterChecksum,
      beforeEnvelope: beforeEnvelope ?? this.beforeEnvelope,
      afterEnvelope: afterEnvelope ?? this.afterEnvelope,
      errorCode: errorCode ?? this.errorCode,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'transactionVersion': transactionVersion,
      'commandVersion': commandVersion,
      'transactionId': transactionId,
      'kind': kind.name,
      'state': state.name,
      'baseRevision': baseRevision,
      'targetRevision': targetRevision,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'commandChecksum': commandChecksum,
      'beforeChecksum': beforeChecksum,
      'afterChecksum': afterChecksum,
      'beforeEnvelope': beforeEnvelope?.toJson(),
      'afterEnvelope': afterEnvelope?.toJson(),
      'errorCode': errorCode,
    };
  }

  factory InventoryTransactionRecord.fromJson(Map<String, dynamic> json) {
    final rawBefore = json['beforeEnvelope'];
    final rawAfter = json['afterEnvelope'];
    return InventoryTransactionRecord(
      transactionVersion: _parseInt(json['transactionVersion'], fallback: -1),
      commandVersion: _parseInt(json['commandVersion'], fallback: -1),
      transactionId: json['transactionId']?.toString() ?? '',
      kind: InventoryTransactionKind.values.firstWhere(
        (kind) => kind.name == json['kind']?.toString(),
        orElse: () =>
            throw const FormatException('Unknown inventory transaction kind.'),
      ),
      state: InventoryTransactionState.values.firstWhere(
        (state) => state.name == json['state']?.toString(),
        orElse: () =>
            throw const FormatException('Unknown inventory transaction state.'),
      ),
      baseRevision: _parseInt(json['baseRevision'], fallback: -1),
      targetRevision: _parseInt(json['targetRevision'], fallback: -1),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      commandChecksum: json['commandChecksum']?.toString() ?? '',
      beforeChecksum: json['beforeChecksum']?.toString() ?? '',
      afterChecksum: json['afterChecksum']?.toString() ?? '',
      beforeEnvelope: rawBefore is Map
          ? InventoryStateEnvelope.fromJson(
              Map<String, dynamic>.from(rawBefore),
            )
          : null,
      afterEnvelope: rawAfter is Map
          ? InventoryStateEnvelope.fromJson(Map<String, dynamic>.from(rawAfter))
          : null,
      errorCode: _optionalString(json['errorCode']),
    );
  }
}

int _parseInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime _parseDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String? _optionalString(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}
