import '../../../pantry/domain/repositories/inventory_commit_repository.dart';
import '../../domain/entities/purchase_history_entry.dart';
import '../../domain/entities/shopping_item_status.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../../domain/services/purchase_history_projector.dart';

class LocalShoppingRepository implements ShoppingRepository {
  const LocalShoppingRepository(this._inventoryRepository);

  final InventoryCommitRepository _inventoryRepository;

  @override
  Future<ShoppingList?> getList(String id) async {
    final lists = await getLists();
    for (final list in lists) {
      if (list.id == id) {
        return list;
      }
    }
    return null;
  }

  @override
  Future<List<ShoppingList>> getLists() async {
    final snapshot = await _inventoryRepository.loadConsistentSnapshot();
    final lists = snapshot.shoppingLists
        .map(
          (list) => list.copyWith(
            items: list.items
                .where((item) => item.status == ShoppingItemStatus.active)
                .toList(growable: false),
          ),
        )
        .toList()
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    return List<ShoppingList>.unmodifiable(lists);
  }

  @override
  Future<List<PurchaseHistoryEntry>> getPurchaseHistory() async {
    final snapshot = await _inventoryRepository.loadConsistentSnapshot();
    final records = await _inventoryRepository.loadJournal();
    return const PurchaseHistoryProjector().project(
      snapshot: snapshot,
      records: records,
    );
  }
}
