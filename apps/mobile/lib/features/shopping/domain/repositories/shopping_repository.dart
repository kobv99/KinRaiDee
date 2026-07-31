import '../entities/purchase_history_entry.dart';
import '../entities/shopping_list.dart';

/// Read boundary for the durable Shopping and Purchase History projections.
///
/// Mutations are intentionally absent. Every write must go through the
/// transaction coordinators.
abstract interface class ShoppingRepository {
  Future<List<ShoppingList>> getLists();

  Future<ShoppingList?> getList(String id);

  Future<List<PurchaseHistoryEntry>> getPurchaseHistory();
}
