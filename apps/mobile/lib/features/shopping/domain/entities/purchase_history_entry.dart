class PurchaseHistoryEntry {
  PurchaseHistoryEntry({
    this.metadataVersion = currentPurchaseHistoryEntryVersion,
    required this.id,
    required this.purchasedAt,
    required this.ingredientId,
    required this.canonicalIngredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unitId,
    required List<String> sourceRecipeIds,
    required this.shoppingListId,
    required this.shoppingItemId,
    required this.pantryTransactionId,
    required List<String> pantryLotIds,
  }) : sourceRecipeIds = List<String>.unmodifiable(sourceRecipeIds),
       pantryLotIds = List<String>.unmodifiable(pantryLotIds);

  final int metadataVersion;
  final String id;
  final DateTime purchasedAt;
  final String ingredientId;
  final String canonicalIngredientId;
  final String ingredientName;
  final double quantity;
  final String unitId;
  final List<String> sourceRecipeIds;
  final String shoppingListId;
  final String shoppingItemId;
  final String pantryTransactionId;
  final List<String> pantryLotIds;
}

const int currentPurchaseHistoryEntryVersion = 1;
