import '../entities/shopping_list.dart';

/// Read boundary for the durable Shopping projection.
///
/// Mutations are intentionally absent. Every write must go through
/// InventoryTransactionCoordinator.
abstract interface class ShoppingRepository {
  Future<List<ShoppingList>> getLists();

  Future<ShoppingList?> getList(String id);
}
