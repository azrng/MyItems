import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/app_store.dart';
import 'package:my_items/models.dart';
import 'package:my_items/repository.dart';

void main() {
  test('reorders categories and persists normalized sort order', () async {
    final repository = FakeCategoryRepository([
      const Category(id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
      const Category(id: 'daily', name: '日用品', icon: '🧴', sortOrder: 2, isPreset: true),
      const Category(id: 'other', name: '其他', icon: '📦', sortOrder: 3, isPreset: true),
    ]);
    final store = AppStore(repository);

    await store.initialize();
    await store.reorderCategory(0, 2);

    expect(store.categories.map((category) => category.id), ['daily', 'food', 'other']);
    expect(repository.persistedOrder.map((category) => '${category.id}:${category.sortOrder}'), ['daily:1', 'food:2', 'other:3']);
  });
}

class FakeCategoryRepository extends ItemRepository {
  FakeCategoryRepository(this._categories);

  List<Category> _categories;
  List<Category> persistedOrder = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Category>> getCategories() async => _categories;

  @override
  Future<List<ExpiryGroup>> getExpiryGroups({String? searchText}) async => const [];

  @override
  Future<List<ItemDisplay>> getItemDisplays({ItemQuery query = const ItemQuery()}) async => const [];

  @override
  Future<LibraryStatistics> getStatistics() async => LibraryStatistics.empty;

  @override
  Future<void> updateCategoryOrder(List<Category> categories) async {
    persistedOrder = categories;
    _categories = categories;
  }
}
