import '../entities/shopping_item.dart';
import '../entities/shopping_list.dart';

enum ShoppingMutationType {
  upsertList,
  removeList,
  addItem,
  removeItem,
  updateQuantity,
  markPurchased,
  markUnpurchased,
  archiveCompleted,
  restoreArchived,
  clearCompleted,
}

class ShoppingMutation {
  const ShoppingMutation({
    this.transactionId = '',
    this.expectedRevision = -1,
    required this.type,
    required this.listId,
    this.expectedListRevision = -1,
    this.list,
    this.itemId,
    this.item,
    this.quantity,
    this.unitId,
    required this.createdAt,
  });

  factory ShoppingMutation.upsert({
    String transactionId = '',
    int expectedRevision = -1,
    required ShoppingList list,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.upsertList,
      listId: list.id,
      expectedListRevision: list.revision,
      list: list,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.remove({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.removeList,
      listId: listId,
      expectedListRevision: expectedListRevision,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.addItem({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required ShoppingItem item,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.addItem,
      listId: listId,
      expectedListRevision: expectedListRevision,
      itemId: item.id,
      item: item,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.removeItem({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required String itemId,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.removeItem,
      listId: listId,
      expectedListRevision: expectedListRevision,
      itemId: itemId,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.updateQuantity({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required String itemId,
    required double quantity,
    String? unitId,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.updateQuantity,
      listId: listId,
      expectedListRevision: expectedListRevision,
      itemId: itemId,
      quantity: quantity,
      unitId: unitId,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.markPurchased({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required String itemId,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.markPurchased,
      listId: listId,
      expectedListRevision: expectedListRevision,
      itemId: itemId,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.markUnpurchased({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required String itemId,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.markUnpurchased,
      listId: listId,
      expectedListRevision: expectedListRevision,
      itemId: itemId,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.archiveCompleted({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.archiveCompleted,
      listId: listId,
      expectedListRevision: expectedListRevision,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.restoreArchived({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.restoreArchived,
      listId: listId,
      expectedListRevision: expectedListRevision,
      createdAt: createdAt,
    );
  }

  factory ShoppingMutation.clearCompleted({
    String transactionId = '',
    int expectedRevision = -1,
    required String listId,
    required int expectedListRevision,
    required DateTime createdAt,
  }) {
    return ShoppingMutation(
      transactionId: transactionId,
      expectedRevision: expectedRevision,
      type: ShoppingMutationType.clearCompleted,
      listId: listId,
      expectedListRevision: expectedListRevision,
      createdAt: createdAt,
    );
  }

  final String transactionId;
  final int expectedRevision;
  final ShoppingMutationType type;
  final String listId;
  final int expectedListRevision;
  final ShoppingList? list;
  final String? itemId;
  final ShoppingItem? item;
  final double? quantity;
  final String? unitId;
  final DateTime createdAt;

  ShoppingMutation copyWith({
    String? transactionId,
    int? expectedRevision,
    int? expectedListRevision,
    ShoppingList? list,
    String? itemId,
    ShoppingItem? item,
    double? quantity,
    String? unitId,
  }) {
    return ShoppingMutation(
      transactionId: transactionId ?? this.transactionId,
      expectedRevision: expectedRevision ?? this.expectedRevision,
      type: type,
      listId: listId,
      expectedListRevision: expectedListRevision ?? this.expectedListRevision,
      list: list ?? this.list,
      itemId: itemId ?? this.itemId,
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      unitId: unitId ?? this.unitId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'transactionId': transactionId,
      'expectedRevision': expectedRevision,
      'type': type.name,
      'listId': listId,
      'expectedListRevision': expectedListRevision,
      'list': list?.toJson(),
      'itemId': itemId,
      'item': item?.toJson(),
      'quantity': quantity,
      'unitId': unitId,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}
