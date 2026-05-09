import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/app_store.dart';
import 'package:my_items/main.dart';
import 'package:my_items/models.dart';
import 'package:my_items/pages.dart';
import 'package:my_items/repository.dart';

void main() {
  testWidgets('root navigation includes expiring page entry', (tester) async {
    await tester.pumpWidget(MyItemsApp(store: AppStore(ItemRepository())));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('临期'), findsOneWidget);
    expect(find.text('物品库'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
  });

  testWidgets('add item page opened from library can access app scope',
      (tester) async {
    await tester.pumpWidget(MyItemsApp(store: AppStore(ItemRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('物品库'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('添加物品'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category page supports icon picker and drag handles',
      (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('分类'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.drag_handle), findsWidgets);
    expect(
        find.byKey(const ValueKey('category-dismiss-custom')), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);

    expect(find.text('图标'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);

    await tester.tap(find.byType(IconPreviewButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('选择分类图标'), findsOneWidget);
    expect(find.text('🍔'), findsWidgets);
  });

  testWidgets('library item supports swipe delete action', (tester) async {
    final repository = FakeNavigationRepository();
    await tester.pumpWidget(MyItemsApp(store: AppStore(repository)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('物品库'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('测试物品'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('item-dismiss-test-item')), findsOneWidget);
    expect(find.text('¥0.00/天'), findsNothing);

    await tester.drag(
        find.byKey(const ValueKey('item-dismiss-test-item')),
        const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('确定永久删除「测试物品」吗？该操作不可恢复。'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('真的永久删除这个物品吗？'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(repository.deletedItemIds, ['test-item']);
  });

  testWidgets('library overview uses compact metric strip', (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('物品库'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('library-metric-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-metric-spent')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-metric-valid')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-metric-total')), findsOneWidget);
  });

  testWidgets('drawer opens storage management page', (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('存储管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('存储管理'), findsWidgets);
    expect(find.text('导出完整备份'), findsOneWidget);
    expect(find.text('恢复完整备份'), findsOneWidget);
    expect(find.text('选择备份文件'), findsOneWidget);
    expect(find.text('导出 CSV'), findsNWidgets(2));
    expect(find.text('导入 CSV'), findsNWidgets(2));
    expect(find.text('选择 CSV 文件'), findsOneWidget);
    expect(find.text('CSV 文件路径'), findsNothing);
    expect(find.text('清空所有数据'), findsOneWidget);
  });

  testWidgets('drawer opens location management page', (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('存放位置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('存放位置'), findsWidgets);
    expect(find.text('新增位置'), findsOneWidget);
    expect(find.text('冰箱'), findsOneWidget);
  });

  testWidgets('drawer opens archive and consumption record pages',
      (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('耗尽归档'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('耗尽归档'), findsWidgets);
    expect(find.text('消耗完成物品'), findsOneWidget);

    Navigator.of(tester.element(find.text('耗尽归档').first)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('消耗记录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('消耗记录'), findsWidgets);
    expect(find.text('用掉一件'), findsOneWidget);
    expect(find.text('消耗完成物品'), findsOneWidget);
    expect(find.textContaining('物品 ID'), findsNothing);
  });

  testWidgets('home app bar add button opens add item page', (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('添加物品'), findsOneWidget);
    expect(find.text('扫码录入'), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
  });

  testWidgets('add item page has purchase date field', (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('购买日期'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '未记录'), findsOneWidget);
    expect(find.text('单价'), findsOneWidget);
    expect(find.text('存放位置'), findsOneWidget);
    expect(find.text('初始数量'), findsOneWidget);
  });

  testWidgets('about page exposes project link and theme choices',
      (tester) async {
    await tester
        .pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('关于'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('技术栈'), findsNothing);
    expect(find.text('github.com/azrng/MyItems'), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
  });
}

class FakeNavigationRepository extends ItemRepository {
  final _categories = [
    const Category(
        id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
    const Category(
        id: 'daily', name: '日用品', icon: '🧴', sortOrder: 2, isPreset: true),
    const Category(
        id: 'custom', name: '自定义', icon: '🏷️', sortOrder: 3, isPreset: false),
  ];
  final _locations = const [
    StorageLocation(id: 'fridge', name: '冰箱', sortOrder: 1),
  ];
  final _today = DateTime(2026, 5, 9);
  final deletedItemIds = <String>[];
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
  Future<List<StorageLocation>> getLocations(
          {bool includeInactive = false}) async =>
      _locations;

  @override
  Future<List<ExpiryGroup>> getExpiryGroups({String? searchText}) async =>
      const [];

  @override
  Future<List<ItemDisplay>> getItemDisplays(
      {ItemQuery query = const ItemQuery()}) async {
    final item = Item(
      id: 'test-item',
      name: '测试物品',
      categoryId: 'food',
      createdAt: _today,
      updatedAt: _today,
    );
    return [
      ItemDisplay.fromItem(
          item: item, category: _categories.first, today: _today)
    ];
  }

  @override
  Future<List<ItemDisplay>> getHomeItemDisplays(
          {String? searchText, int limit = 1000}) async =>
      getItemDisplays(query: ItemQuery(searchText: searchText, limit: limit));

  @override
  Future<LibraryStatistics> getStatistics() async => LibraryStatistics.empty;

  @override
  Future<void> deleteItem(String itemId) async {
    deletedItemIds.add(itemId);
  }

  @override
  Future<List<ItemDisplay>> getArchivedItemDisplays() async {
    final item = Item(
      id: 'archived-item',
      name: '消耗完成物品',
      categoryId: 'food',
      isArchived: true,
      quantity: 1,
      initialQuantity: 1,
      remainingQuantity: 0,
      createdAt: _today,
      updatedAt: _today,
    );
    return [
      ItemDisplay.fromItem(
          item: item, category: _categories.first, today: _today)
    ];
  }

  @override
  Future<List<ConsumptionRecord>> getAllConsumptionRecords() async => [
        ConsumptionRecord(
          id: 'record-1',
          itemId: 'archived-item',
          quantity: 1,
          type: ConsumptionType.consumeOne,
          consumedAt: _today,
        ),
      ];

  @override
  Future<List<ConsumptionRecordDisplay>> getConsumptionRecordDisplays() async =>
      [
        ConsumptionRecordDisplay(
          record: ConsumptionRecord(
            id: 'record-1',
            itemId: 'archived-item',
            quantity: 1,
            type: ConsumptionType.consumeOne,
            consumedAt: _today,
          ),
          itemName: '消耗完成物品',
        ),
      ];
}
