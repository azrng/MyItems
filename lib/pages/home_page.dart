import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/item_card.dart';
import 'add_item_page.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SoftCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('空间整理清单',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            '采用极简主义整理美学，让生活恢复纯白与淡蓝的静谧。',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      height: 1.4,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddItemPage())),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('放新物品'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _HomeMetrics(store: store),
              const SizedBox(height: 16),
              if (store.errorMessage != null)
                ErrorBanner(message: store.errorMessage!),
              _UrgentPanel(items: _urgentItems(store.homeItems)),
              const SizedBox(height: 16),
              _RecentPanel(items: store.homeItems.take(3).toList()),
            ],
          ),
        );
      },
    );
  }

  List<ItemDisplay> _urgentItems(List<ItemDisplay> items) {
    final result = items
        .where((item) =>
            item.expiryStatus == ExpiryStatus.expired ||
            item.expiryStatus == ExpiryStatus.expiring)
        .toList()
      ..sort((a, b) {
        final aDate = a.item.expiryDate ?? DateTime(9999);
        final bDate = b.item.expiryDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });
    return result.take(3).toList();
  }
}

class _HomeMetrics extends StatelessWidget {
  const _HomeMetrics({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final items = store.homeItems;
    final warning =
        items.where((item) => item.expiryStatus == ExpiryStatus.expiring).length;
    final expired =
        items.where((item) => item.expiryStatus == ExpiryStatus.expired).length;
    final safe =
        items.where((item) => item.expiryStatus == ExpiryStatus.safe).length;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        MetricTile(
          icon: Icons.inventory_2_outlined,
          label: '物品总数',
          value: '${items.length}',
          color: const Color(0xFF0EA5E9),
        ),
        MetricTile(
          icon: Icons.notifications_none,
          label: '即将到期',
          value: '$warning',
          color: const Color(0xFFF59E0B),
        ),
        MetricTile(
          icon: Icons.warning_amber_outlined,
          label: '已过期',
          value: '$expired',
          color: const Color(0xFFF43F5E),
        ),
        MetricTile(
          icon: Icons.verified_outlined,
          label: '安全储存',
          value: '$safe',
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }
}

class _UrgentPanel extends StatelessWidget {
  const _UrgentPanel({required this.items});

  final List<ItemDisplay> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftSectionHeader(
            title: '需要注意的物品',
            subtitle: '临期或已到期，建议尽快处理',
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.event_available_outlined,
                title: '库存状态非常安心',
                subtitle: '当前没有需要立刻关注的临期或过期物品。')
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ItemCard(
                    display: item,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ItemDetailPage(itemId: item.id))),
                  ),
                )),
        ],
      ),
    );
  }
}

class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.items});

  final List<ItemDisplay> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SoftSectionHeader(
            title: '最近收入物品',
            subtitle: '最近录入系统的 3 件物品',
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: '暂无物品',
                subtitle: '点击顶部按钮记录第一件物品。')
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ItemCard(
                    display: item,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ItemDetailPage(itemId: item.id))),
                  ),
                )),
        ],
      ),
    );
  }
}
