import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/item_card.dart';
import 'item_detail_page.dart';

class ArchivedItemsPage extends StatelessWidget {
  const ArchivedItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('耗尽归档')),
      body: FutureBuilder<List<ItemDisplay>>(
        future: store.getArchivedItemDisplays(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <ItemDisplay>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.archive_outlined,
              title: '暂无耗尽物品',
              subtitle: '消耗完成的物品会出现在这里。',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ItemCard(
                      display: item,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ItemDetailPage(itemId: item.id))),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
