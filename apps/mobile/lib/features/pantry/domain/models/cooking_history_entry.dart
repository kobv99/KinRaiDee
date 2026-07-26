import '../../../../core/models/ingredient.dart';
import 'pantry_quantity_transaction.dart';

const int currentCookingHistorySchemaVersion = 2;

enum CookingHistoryStatus { completed, adjusted, cancelled }

class CookingHistoryChange {
  const CookingHistoryChange({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.beforeQuantity,
    required this.originalAfterQuantity,
    required this.afterQuantity,
    this.canonicalIngredientId = '',
    this.canonicalUnitId = '',
    this.canonicalMappingStatus = CanonicalMappingStatus.legacy,
  });

  final String ingredientId;
  final String ingredientName;
  final String unit;
  final double beforeQuantity;
  final double originalAfterQuantity;
  final double afterQuantity;
  final String canonicalIngredientId;
  final String canonicalUnitId;
  final CanonicalMappingStatus canonicalMappingStatus;

  double get originalConsumedQuantity {
    final value = beforeQuantity - originalAfterQuantity;
    return value > 0 ? value : 0;
  }

  double get consumedQuantity {
    final value = beforeQuantity - afterQuantity;
    return value > 0 ? value : 0;
  }

  CookingHistoryChange copyWith({
    double? originalAfterQuantity,
    double? afterQuantity,
    String? canonicalIngredientId,
    String? canonicalUnitId,
    CanonicalMappingStatus? canonicalMappingStatus,
  }) {
    return CookingHistoryChange(
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      unit: unit,
      beforeQuantity: beforeQuantity,
      originalAfterQuantity:
          originalAfterQuantity ?? this.originalAfterQuantity,
      afterQuantity: afterQuantity ?? this.afterQuantity,
      canonicalIngredientId:
          canonicalIngredientId ?? this.canonicalIngredientId,
      canonicalUnitId: canonicalUnitId ?? this.canonicalUnitId,
      canonicalMappingStatus:
          canonicalMappingStatus ?? this.canonicalMappingStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      'unit': unit,
      'beforeQuantity': beforeQuantity,
      'originalAfterQuantity': originalAfterQuantity,
      'afterQuantity': afterQuantity,
      'canonicalIngredientId': canonicalIngredientId,
      'canonicalUnitId': canonicalUnitId,
      'canonicalMappingStatus': canonicalMappingStatus.name,
    };
  }

  factory CookingHistoryChange.fromJson(Map<String, dynamic> json) {
    final afterQuantity = _parseDouble(json['afterQuantity']);
    return CookingHistoryChange(
      ingredientId: json['ingredientId']?.toString() ?? '',
      ingredientName: json['ingredientName']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      beforeQuantity: _parseDouble(json['beforeQuantity']),
      originalAfterQuantity: json.containsKey('originalAfterQuantity')
          ? _parseDouble(json['originalAfterQuantity'])
          : afterQuantity,
      afterQuantity: afterQuantity,
      canonicalIngredientId: json['canonicalIngredientId']?.toString() ?? '',
      canonicalUnitId: json['canonicalUnitId']?.toString() ?? '',
      canonicalMappingStatus: CanonicalMappingStatus.values.firstWhere(
        (status) => status.name == json['canonicalMappingStatus']?.toString(),
        orElse: () => CanonicalMappingStatus.legacy,
      ),
    );
  }
}

class CookingHistoryEntry {
  const CookingHistoryEntry({
    this.schemaVersion = currentCookingHistorySchemaVersion,
    this.originatingTransactionId = '',
    this.adjustedByTransactionId,
    this.cancelledByTransactionId,
    this.reversedByTransactionId,
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.changes,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  final int schemaVersion;
  final String originatingTransactionId;
  final String? adjustedByTransactionId;
  final String? cancelledByTransactionId;
  final String? reversedByTransactionId;
  final String id;
  final String recipeId;
  final String recipeName;
  final int servings;
  final List<CookingHistoryChange> changes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CookingHistoryStatus status;

  bool get isCancelled => status == CookingHistoryStatus.cancelled;
  bool get canEdit => !isCancelled;

  double get totalConsumedQuantity {
    return changes.fold<double>(
      0,
      (total, change) => total + change.consumedQuantity,
    );
  }

  factory CookingHistoryEntry.fromTransaction(
    PantryQuantityTransaction transaction,
  ) {
    return CookingHistoryEntry(
      schemaVersion: currentCookingHistorySchemaVersion,
      originatingTransactionId: transaction.transactionId,
      id: transactionHistoryId(transaction),
      recipeId: transaction.recipeId,
      recipeName: transaction.recipeName,
      servings: transaction.servings,
      changes: transaction.changes
          .map(
            (change) => CookingHistoryChange(
              ingredientId: change.ingredientId,
              ingredientName: change.ingredientName,
              unit: change.unit,
              beforeQuantity: change.beforeQuantity,
              originalAfterQuantity: change.afterQuantity,
              afterQuantity: change.afterQuantity,
              canonicalIngredientId: change.canonicalIngredientId,
              canonicalUnitId: change.canonicalUnitId,
              canonicalMappingStatus: change.canonicalIngredientId.isEmpty
                  ? CanonicalMappingStatus.legacy
                  : CanonicalMappingStatus.mapped,
            ),
          )
          .toList(growable: false),
      createdAt: transaction.createdAt,
      updatedAt: transaction.createdAt,
      status: CookingHistoryStatus.completed,
    );
  }

  CookingHistoryEntry copyWith({
    int? schemaVersion,
    String? adjustedByTransactionId,
    String? cancelledByTransactionId,
    String? reversedByTransactionId,
    List<CookingHistoryChange>? changes,
    DateTime? updatedAt,
    CookingHistoryStatus? status,
  }) {
    return CookingHistoryEntry(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      originatingTransactionId: originatingTransactionId,
      adjustedByTransactionId:
          adjustedByTransactionId ?? this.adjustedByTransactionId,
      cancelledByTransactionId:
          cancelledByTransactionId ?? this.cancelledByTransactionId,
      reversedByTransactionId:
          reversedByTransactionId ?? this.reversedByTransactionId,
      id: id,
      recipeId: recipeId,
      recipeName: recipeName,
      servings: servings,
      changes: changes ?? this.changes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'originatingTransactionId': originatingTransactionId,
      'adjustedByTransactionId': adjustedByTransactionId,
      'cancelledByTransactionId': cancelledByTransactionId,
      'reversedByTransactionId': reversedByTransactionId,
      'id': id,
      'recipeId': recipeId,
      'recipeName': recipeName,
      'servings': servings,
      'changes': changes
          .map((change) => change.toJson())
          .toList(growable: false),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'status': status.name,
    };
  }

  factory CookingHistoryEntry.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final id = json['id']?.toString() ?? '';
    final rawChanges = json['changes'];
    final changes = rawChanges is List
        ? rawChanges
              .whereType<Map>()
              .map(
                (item) => CookingHistoryChange.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : <CookingHistoryChange>[];

    return CookingHistoryEntry(
      schemaVersion: _parseInt(json['schemaVersion'], fallback: 1),
      originatingTransactionId:
          json['originatingTransactionId']?.toString() ?? id,
      adjustedByTransactionId: _optionalString(json['adjustedByTransactionId']),
      cancelledByTransactionId: _optionalString(
        json['cancelledByTransactionId'],
      ),
      reversedByTransactionId: _optionalString(json['reversedByTransactionId']),
      id: id,
      recipeId: json['recipeId']?.toString() ?? '',
      recipeName: json['recipeName']?.toString() ?? '',
      servings: _parseInt(json['servings'], fallback: 1),
      changes: changes,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt,
      status: CookingHistoryStatus.values.firstWhere(
        (status) => status.name == json['status']?.toString(),
        orElse: () => CookingHistoryStatus.completed,
      ),
    );
  }
}

String transactionHistoryId(PantryQuantityTransaction transaction) {
  if (transaction.transactionId.isNotEmpty) {
    return transaction.transactionId;
  }
  return '${transaction.createdAt.microsecondsSinceEpoch}_${transaction.recipeId}';
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _parseInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String? _optionalString(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}
