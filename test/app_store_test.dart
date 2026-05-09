import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/app_store.dart';
import 'package:my_items/models.dart';
import 'package:my_items/repository.dart';

void main() {
  test('loads home items by created time descending', () async {
    final today = DateTime(2026, 5, 9);
    final repository = FakeHomeRepository([
      Item(
        id: 'old',
        name: '旧物品',
        categoryId: 'food',
        createdAt: today.subtract(const Duration(days: 2)),
        updatedAt: today.subtract(const Duration(days: 2)),
      ),
      Item(
        id: 'new',
        name: '新物品',
        categoryId: 'food',
        createdAt: today,
        updatedAt: today,
      ),
    ]);
    final store = AppStore(repository);

    await store.initialize();

    expect(store.homeItems.map((item) => item.id), ['new', 'old']);
  });

  test('loads library items by created time descending', () async {
    final today = DateTime(2026, 5, 9);
    final repository = FakeHomeRepository([
      Item(
        id: 'old',
        name: '旧物品',
        categoryId: 'food',
        createdAt: today.subtract(const Duration(days: 2)),
        updatedAt: today.subtract(const Duration(days: 2)),
      ),
      Item(
        id: 'new',
        name: '新物品',
        categoryId: 'food',
        createdAt: today,
        updatedAt: today,
      ),
    ]);
    final store = AppStore(repository);

    await store.initialize();

    expect(store.libraryItems.map((item) => item.id), ['new', 'old']);
  });

  test('loads expiry groups by expiry date ascending', () async {
    final today = DateTime(2026, 5, 9);
    final repository = FakeHomeRepository([
      Item(
        id: 'later',
        name: '后到期',
        categoryId: 'food',
        expiryDate: today.add(const Duration(days: 6)),
        createdAt: today,
        updatedAt: today,
      ),
      Item(
        id: 'sooner',
        name: '先到期',
        categoryId: 'food',
        expiryDate: today.add(const Duration(days: 1)),
        createdAt: today.subtract(const Duration(days: 1)),
        updatedAt: today.subtract(const Duration(days: 1)),
      ),
    ]);
    final store = AppStore(repository);

    await store.initialize();

    final expiring = store.expiryGroups
        .singleWhere((group) => group.status == ExpiryStatus.expiring);
    expect(expiring.items.map((item) => item.id), ['sooner', 'later']);
  });

  test('reorders categories and persists normalized sort order', () async {
    final repository = FakeCategoryRepository([
      const Category(
          id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
      const Category(
          id: 'daily', name: '日用品', icon: '🧴', sortOrder: 2, isPreset: true),
      const Category(
          id: 'other', name: '其他', icon: '📦', sortOrder: 3, isPreset: true),
    ]);
    final store = AppStore(repository);

    await store.initialize();
    await store.reorderCategory(0, 2);

    expect(store.categories.map((category) => category.id),
        ['daily', 'food', 'other']);
    expect(
        repository.persistedOrder
            .map((category) => '${category.id}:${category.sortOrder}'),
        ['daily:1', 'food:2', 'other:3']);
  });

  test('statistics uses unit price multiplied by remaining quantity', () async {
    final today = DateTime(2026, 5, 9);
    final repository = FakeHomeRepository([
      Item(
        id: 'bread',
        name: '面包',
        categoryId: 'food',
        purchasePrice: 5,
        quantity: 3,
        initialQuantity: 3,
        remainingQuantity: 2,
        createdAt: today,
        updatedAt: today,
      ),
    ]);
    final store = AppStore(repository);

    await store.initialize();

    expect(store.statistics.totalSpent, 10);
    expect(store.statistics.totalItems, 1);
    expect(store.statistics.validItems, 1);
  });

  test('consumes one item and records consumption', () async {
    final today = DateTime(2026, 5, 9);
    final repository = FakeHomeRepository([
      Item(
        id: 'milk',
        name: '牛奶',
        categoryId: 'food',
        quantity: 2,
        initialQuantity: 2,
        remainingQuantity: 2,
        createdAt: today,
        updatedAt: today,
      ),
    ]);
    final store = AppStore(repository);

    await store.initialize();
    await store.consumeOne('milk');

    expect(repository.items.single.remainingQuantity, 1);
    expect(repository.records.single.itemId, 'milk');
    expect(repository.records.single.quantity, 1);
    expect(repository.records.single.type, ConsumptionType.consumeOne);
  });

  test('consume all archives depleted item', () async {
    final today = DateTime(2026, 5, 9);
    final repository = FakeHomeRepository([
      Item(
        id: 'egg',
        name: '鸡蛋',
        categoryId: 'food',
        quantity: 6,
        initialQuantity: 6,
        remainingQuantity: 4,
        createdAt: today,
        updatedAt: today,
      ),
    ]);
    final store = AppStore(repository);

    await store.initialize();
    await store.consumeAll('egg');

    expect(repository.items.single.remainingQuantity, 0);
    expect(repository.items.single.isArchived, isTrue);
    expect(repository.records.single.quantity, 4);
    expect(repository.records.single.type, ConsumptionType.consumeAll);
  });

  test('home and expiry search are independent', () async {
    final repository = FakeHomeRepository([]);
    final store = AppStore(repository);

    await store.initialize();
    await store.setHomeSearch('面包');
    await store.setExpirySearch('牛奶');

    expect(store.homeSearch, '面包');
    expect(store.expirySearch, '牛奶');
    expect(repository.lastHomeSearch, '面包');
    expect(repository.lastExpirySearch, '牛奶');
  });
}

class FakeCategoryRepository extends ItemRepository {
  FakeCategoryRepository(this._categories);

  List<Category> _categories;
  List<Category> persistedOrder = [];
  ThemePreference _themePreference = ThemePreference.system;

  @override
  Future<void> initialize() async {}

  @override
  Future<ThemePreference> getThemePreference() async => _themePreference;

  @override
  Future<void> saveThemePreference(ThemePreference preference) async {
    _themePreference = preference;
  }

  @override
  Future<List<Category>> getCategories({bool includeInactive = false}) async =>
      _categories;

  @override
  Future<List<ExpiryGroup>> getExpiryGroups({String? searchText}) async =>
      const [];

  @override
  Future<List<StorageLocation>> getLocations(
          {bool includeInactive = false}) async =>
      const [];

  @override
  Future<List<ItemDisplay>> getItemDisplays(
          {ItemQuery query = const ItemQuery()}) async =>
      const [];

  @override
  Future<List<ItemDisplay>> getHomeItemDisplays(
          {String? searchText, int limit = 1000}) async =>
      const [];

  @override
  Future<LibraryStatistics> getStatistics() async => LibraryStatistics.empty;

  @override
  Future<void> updateCategoryOrder(List<Category> categories) async {
    persistedOrder = categories;
    _categories = categories;
  }
}

class FakeHomeRepository extends ItemRepository {
  FakeHomeRepository(this._items);

  final List<Item> _items;
  List<Item> get items => _items;
  final List<ConsumptionRecord> records = [];
  final _category = const Category(
      id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true);
  ThemePreference _themePreference = ThemePreference.system;
  String? lastHomeSearch;
  String? lastExpirySearch;

  @override
  Future<void> initialize() async {}

  @override
  Future<ThemePreference> getThemePreference() async => _themePreference;

  @override
  Future<void> saveThemePreference(ThemePreference preference) async {
    _themePreference = preference;
  }

  @override
  Future<List<Category>> getCategories({bool includeInactive = false}) async =>
      [_category];

  @override
  Future<List<StorageLocation>> getLocations(
          {bool includeInactive = false}) async =>
      const [];

  @override
  Future<List<ExpiryGroup>> getExpiryGroups({String? searchText}) async {
    lastExpirySearch = searchText;
    final displays = await getItemDisplays(
        query:
            ItemQuery(searchText: searchText, onlyExpiring: true, limit: 1000));
    return [ExpiryStatus.expired, ExpiryStatus.expiring]
        .map((status) => ExpiryGroup(
              status: status,
              title: getGroupTitle(status),
              icon: getGroupIcon(status),
              items: displays
                  .where((item) => item.expiryStatus == status)
                  .toList(),
            ))
        .toList();
  }

  @override
  Future<List<ItemDisplay>> getItemDisplays(
      {ItemQuery query = const ItemQuery()}) async {
    return _items
        .where((item) => !item.isArchived)
        .where((item) => item.name.contains(query.searchText ?? ''))
        .map((item) => ItemDisplay.fromItem(
            item: item, category: _category, today: DateTime(2026, 5, 9)))
        .toList();
  }

  @override
  Future<List<ItemDisplay>> getHomeItemDisplays(
      {String? searchText, int limit = 1000}) async {
    lastHomeSearch = searchText;
    final displays = await getItemDisplays(
        query: ItemQuery(searchText: searchText, limit: limit));
    displays.sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));
    return displays.take(limit).toList();
  }

  @override
  Future<LibraryStatistics> getStatistics() async {
    final displays =
        await getItemDisplays(query: const ItemQuery(limit: 10000));
    final valid = displays
        .where((item) => item.expiryStatus != ExpiryStatus.expired)
        .fold<double>(
            0,
            (sum, item) =>
                sum +
                (item.item.purchasePrice ?? 0) * item.item.remainingQuantity);
    return LibraryStatistics(
      totalSpent: valid,
      totalItems: displays.length,
      validItems: displays
          .where((item) => item.expiryStatus != ExpiryStatus.expired)
          .length,
    );
  }

  @override
  Future<Item?> getItem(String id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> consumeItem(String itemId,
      {required int quantity, required ConsumptionType type}) async {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    final item = _items[index];
    final consumed =
        quantity > item.remainingQuantity ? item.remainingQuantity : quantity;
    final remaining = item.remainingQuantity - consumed;
    _items[index] = item.copyWith(
      remainingQuantity: remaining,
      isArchived: remaining == 0 ? true : item.isArchived,
    );
    records.add(ConsumptionRecord(
      id: newId(),
      itemId: itemId,
      quantity: consumed,
      type: type,
      consumedAt: DateTime(2026, 5, 9),
    ));
  }
}
