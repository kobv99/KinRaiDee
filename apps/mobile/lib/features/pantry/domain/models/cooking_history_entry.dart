import 'pantry_quantity_transaction.dart';

enum CookingHistoryStatus { completed, adjusted, cancelled }

class CookingHistoryChange {
  const CookingHistoryChange({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.beforeQuantity,
    required this.originalAfterQuantity,
    required this.afterQuantity,
  });

  final String ingredientId;
  final String ingredientName;
  final String unit;
  final double beforeQuantity;
  final double originalAfterQuantity;
  final double afterQuantity;

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
  }) {
    return CookingHistoryChange(
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      unit: unit,
      beforeQuantity: beforeQuantity,
      originalAfterQuantity:
          originalAfterQuantity ?? this.originalAfterQuantity,
      afterQuantity: afterQuantity ?? this.afterQuantity,
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
    );
  }
}

class CookingHistoryEntry {
  const CookingHistoryEntry({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.changes,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

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
            ),
          )
          .toList(growable: false),
      createdAt: transaction.createdAt,
      updatedAt: transaction.createdAt,
      status: CookingHistoryStatus.completed,
    );
  }

  CookingHistoryEntry copyWith({
    List<CookingHistoryChange>? changes,
    DateTime? updatedAt,
    CookingHistoryStatus? status,
  }) {
    return CookingHistoryEntry(
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
      'id': id,
      'recipeId': recipeId,
      'recipeName': recipeName,
      'servings': servings,
      'changes': changes
          .map((change) => change.toJson())
          .toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory CookingHistoryEntry.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
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
      id: json['id']?.toString() ?? '',
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
