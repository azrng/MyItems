import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/app_store.dart';
import 'package:my_items/main.dart';
import 'package:my_items/models.dart';
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

  testWidgets('add item page opened from library can access app scope', (tester) async {
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

  testWidgets('category page supports icon picker and drag handles', (tester) async {
    await tester.pumpWidget(MyItemsApp(store: AppStore(FakeNavigationRepository())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('分类'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.drag_handle), findsWidgets);

    await tester.tap(find.text('图标'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('选择分类图标'), findsOneWidget);
    expect(find.text('🍔'), findsWidgets);
  });
}

class FakeNavigationRepository extends ItemRepository {
  final _categories = [
    const Category(id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
    const Category(id: 'daily', name: '日用品', icon: '🧴', sortOrder: 2, isPreset: true),
  ];

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
}
