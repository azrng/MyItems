import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_items/app_store.dart';
import 'package:my_items/main.dart';
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
}
