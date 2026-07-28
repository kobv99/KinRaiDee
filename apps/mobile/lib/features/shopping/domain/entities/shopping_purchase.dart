const int currentShoppingPurchaseVersion = 1;

class ShoppingPurchase {
  const ShoppingPurchase({
    this.metadataVersion = currentShoppingPurchaseVersion,
    required this.transactionId,
    required this.pantryLotId,
    required this.createdPantryLot,
    required this.pantryUnitId,
    required this.beforeQuantity,
    required this.afterQuantity,
    required this.purchasedAt,
  });

  final int metadataVersion;
  final String transactionId;
  final String pantryLotId;
  final bool createdPantryLot;
  final String pantryUnitId;
  final double beforeQuantity;
  final double afterQuantity;
  final DateTime purchasedAt;

  double get addedQuantity => afterQuantity - beforeQuantity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'metadataVersion': metadataVersion,
      'transactionId': transactionId,
      'pantryLotId': pantryLotId,
      'createdPantryLot': createdPantryLot,
      'pantryUnitId': pantryUnitId,
      'beforeQuantity': beforeQuantity,
      'afterQuantity': afterQuantity,
      'purchasedAt': purchasedAt.toUtc().toIso8601String(),
    };
  }

  factory ShoppingPurchase.fromJson(Map<String, dynamic> json) {
    return ShoppingPurchase(
      metadataVersion: _integer(json['metadataVersion'], fallback: -1),
      transactionId: json['transactionId']?.toString() ?? '',
      pantryLotId: json['pantryLotId']?.toString() ?? '',
      createdPantryLot: _boolean(json['createdPantryLot']),
      pantryUnitId: json['pantryUnitId']?.toString() ?? '',
      beforeQuantity: _double(json['beforeQuantity']),
      afterQuantity: _double(json['afterQuantity']),
      purchasedAt:
          DateTime.tryParse(json['purchasedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

double _double(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? double.nan;
}

int _integer(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolean(dynamic value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}
