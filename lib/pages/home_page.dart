import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/item_card.dart';
import 'item_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: store.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              SearchField(
                hint: '搜索全部物品',
                initialValue: store.homeSearch,
                onChanged: store.setHomeSearch,
              ),
              const SizedBox(height: 12),
              if (store.errorMessage != null)
                ErrorBanner(message: store.errorMessage!),
              if (store.homeItems.isEmpty)
                const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: '暂无物品',
                    subtitle: '点击物品库右下角按钮或抽屉里的添加入口记录第一件物品。'),
              ...store.homeItems.map((item) => Padding(
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
          ),
        );
      },
    );
  }
}
