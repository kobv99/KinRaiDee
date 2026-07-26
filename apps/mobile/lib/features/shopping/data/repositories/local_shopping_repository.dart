import '../../../pantry/domain/repositories/inventory_commit_repository.dart';
import '../../domain/entities/shopping_list.dart';
import '../../domain/repositories/shopping_repository.dart';

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
    final lists = List<ShoppingList>.of(snapshot.shoppingLists)
      ..sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    return List<ShoppingList>.unmodifiable(lists);
  }
}
