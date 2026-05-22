import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart' as my;
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/item_card.dart';
import 'item_detail_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: store.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              SearchField(
                hint: '搜索名称、品牌、分类或位置',
                initialValue: store.librarySearch,
                onChanged: store.setLibrarySearch,
              ),
              const SizedBox(height: 12),
              StatisticsCard(statistics: store.statistics),
              const SizedBox(height: 12),
              CategoryChips(
                categories: store.categories,
                selectedCategoryId: store.selectedCategoryId,
                onSelected: store.selectCategory,
              ),
              const SizedBox(height: 12),
              if (store.libraryItems.isEmpty)
                const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: '暂无物品',
                    subtitle: '点击右下角按钮添加第一件物品。'),
              ...store.libraryItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey('item-dismiss-${item.id}'),
                      direction: DismissDirection.endToStart,
                      background: const SizedBox.shrink(),
                      secondaryBackground:
                          const SwipeDeleteBackground(label: '删除'),
                      confirmDismiss: (_) async {
                        final confirmed = await showConfirm(
                            context, '删除物品', '确定永久删除「${item.name}」吗？该操作不可恢复。');
                        if (!confirmed) return false;
                        if (!context.mounted) return false;
                        final secondConfirmed =
                            await showConfirm(context, '二次确认', '真的永久删除这个物品吗？');
                        if (!secondConfirmed) return false;
                        try {
                          await store.deleteItem(item.id);
                        } catch (error) {
                          if (context.mounted) {
                            showSnack(context, error.toString());
                          }
                        }
                        return false;
                      },
                      child: ItemCard(
                        display: item,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ItemDetailPage(itemId: item.id))),
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class StatisticsCard extends StatelessWidget {
  const StatisticsCard({super.key, required this.statistics});

  final LibraryStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('library-metric-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(140)),
      ),
      child: Row(
        children: [
          Expanded(
            child: StatItem(
              key: const ValueKey('library-metric-spent'),
              icon: Icons.payments_outlined,
              label: '有效花费',
              value: formatCurrency(statistics.totalSpent),
            ),
          ),
          const MetricDivider(),
          Expanded(
            child: StatItem(
              key: const ValueKey('library-metric-valid'),
              icon: Icons.inventory_2_outlined,
              label: '有效商品',
              value: '${statistics.validItems} 件',
            ),
          ),
          const MetricDivider(),
          Expanded(
            child: StatItem(
              key: const ValueKey('library-metric-total'),
              icon: Icons.all_inbox_outlined,
              label: '全部',
              value: '${statistics.totalItems} 件',
            ),
          ),
        ],
      ),
    );
  }
}

class MetricDivider extends StatelessWidget {
  const MetricDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant.withAlpha(160),
    );
  }
}

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      )),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
        ),
      ],
    );
  }
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<my.Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('全部'),
              selected: selectedCategoryId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...categories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${category.icon ?? '📦'} ${category.name}'),
                  selected: selectedCategoryId == category.id,
                  onSelected: (_) => onSelected(category.id),
                ),
              )),
        ],
      ),
    );
  }
}
