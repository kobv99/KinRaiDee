enum InventoryTransactionKind {
  completeCooking,
  undoCooking,
  adjustCookingHistory,
  cancelCookingHistory,
  pantryMutation,
  canonicalIngredientMigration,
  shoppingMutation,
  shoppingPurchase,
  undoShoppingPurchase,
}

class PantryQuantityChange {
  const PantryQuantityChange({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.beforeQuantity,
    required this.afterQuantity,
    this.canonicalIngredientId = '',
    this.canonicalUnitId = '',
  });

  final String ingredientId;
  final String ingredientName;
  final String unit;
  final double beforeQuantity;
  final double afterQuantity;
  final String canonicalIngredientId;
  final String canonicalUnitId;

  double get consumedQuantity {
    final consumed = beforeQuantity - afterQuantity;
    return consumed > 0 ? consumed : 0;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ingredientId': ingredientId,
      'ingredientName': ingredientName,
      'unit': unit,
      'beforeQuantity': beforeQuantity,
      'afterQuantity': afterQuantity,
      'canonicalIngredientId': canonicalIngredientId,
      'canonicalUnitId': canonicalUnitId,
    };
  }

  factory PantryQuantityChange.fromJson(Map<String, dynamic> json) {
    return PantryQuantityChange(
      ingredientId: json['ingredientId']?.toString() ?? '',
      ingredientName: json['ingredientName']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      beforeQuantity: _parseDouble(json['beforeQuantity']),
      afterQuantity: _parseDouble(json['afterQuantity']),
      canonicalIngredientId: json['canonicalIngredientId']?.toString() ?? '',
      canonicalUnitId: json['canonicalUnitId']?.toString() ?? '',
    );
  }
}

class PantryQuantityTransaction {
  const PantryQuantityTransaction({
    this.transactionId = '',
    this.schemaVersion = 1,
    this.expectedRevision = -1,
    this.kind = InventoryTransactionKind.completeCooking,
    this.reversesTransactionId,
    this.targetHistoryEntryId,
    required this.recipeId,
    required this.recipeName,
    required this.servings,
    required this.changes,
    required this.createdAt,
  });

  final String transactionId;
  final int schemaVersion;
  final int expectedRevision;
  final InventoryTransactionKind kind;
  final String? reversesTransactionId;
  final String? targetHistoryEntryId;
  final String recipeId;
  final String recipeName;
  final int servings;
  final List<PantryQuantityChange> changes;
  final DateTime createdAt;

  bool get hasChanges => changes.isNotEmpty;
  int get changedIngredientCount => changes.length;

  PantryQuantityTransaction copyWith({
    String? transactionId,
    int? schemaVersion,
    int? expectedRevision,
    InventoryTransactionKind? kind,
    String? reversesTransactionId,
    String? targetHistoryEntryId,
    String? recipeId,
    String? recipeName,
    int? servings,
    List<PantryQuantityChange>? changes,
    DateTime? createdAt,
  }) {
    return PantryQuantityTransaction(
      transactionId: transactionId ?? this.transactionId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      expectedRevision: expectedRevision ?? this.expectedRevision,
      kind: kind ?? this.kind,
      reversesTransactionId:
          reversesTransactionId ?? this.reversesTransactionId,
      targetHistoryEntryId: targetHistoryEntryId ?? this.targetHistoryEntryId,
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      servings: servings ?? this.servings,
      changes: changes ?? this.changes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'transactionId': transactionId,
      'schemaVersion': schemaVersion,
      'expectedRevision': expectedRevision,
      'kind': kind.name,
      'reversesTransactionId': reversesTransactionId,
      'targetHistoryEntryId': targetHistoryEntryId,
      'recipeId': recipeId,
      'recipeName': recipeName,
      'servings': servings,
      'changes': changes
          .map((change) => change.toJson())
          .toList(growable: false),
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory PantryQuantityTransaction.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    return PantryQuantityTransaction(
      transactionId: json['transactionId']?.toString() ?? '',
      schemaVersion: _parseInt(json['schemaVersion'], fallback: 1),
      expectedRevision: _parseInt(json['expectedRevision'], fallback: -1),
      kind: InventoryTransactionKind.values.firstWhere(
        (kind) => kind.name == json['kind']?.toString(),
        orElse: () => InventoryTransactionKind.completeCooking,
      ),
      reversesTransactionId: _optionalString(json['reversesTransactionId']),
      targetHistoryEntryId: _optionalString(json['targetHistoryEntryId']),
      recipeId: json['recipeId']?.toString() ?? '',
      recipeName: json['recipeName']?.toString() ?? '',
      servings: _parseInt(json['servings'], fallback: 1),
      changes: rawChanges is List
          ? rawChanges
                .whereType<Map>()
                .map(
                  (item) => PantryQuantityChange.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <PantryQuantityChange>[],
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? double.nan;
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
