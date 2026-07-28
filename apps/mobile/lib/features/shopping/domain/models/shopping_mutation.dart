import '../entities/shopping_list.dart';

enum ShoppingMutationType { upsertList, removeList }

class ShoppingMutation {
  const ShoppingMutation({
    this.transactionId = '',
    this.expectedRevision = -1,
    required this.type,
    required this.listId,
    this.expectedListRevision = -1,
    this.list,
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

  final String transactionId;
  final int expectedRevision;
  final ShoppingMutationType type;
  final String listId;
  final int expectedListRevision;
  final ShoppingList? list;
  final DateTime createdAt;

  ShoppingMutation copyWith({
    String? transactionId,
    int? expectedRevision,
    int? expectedListRevision,
    ShoppingList? list,
  }) {
    return ShoppingMutation(
      transactionId: transactionId ?? this.transactionId,
      expectedRevision: expectedRevision ?? this.expectedRevision,
      type: type,
      listId: listId,
      expectedListRevision: expectedListRevision ?? this.expectedListRevision,
      list: list ?? this.list,
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
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}
