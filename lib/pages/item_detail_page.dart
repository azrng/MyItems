import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../repository/schema.dart' show fallbackCategory;
import '../widgets/common.dart';
import '../widgets/item_card.dart';
import 'add_item_page.dart';

const fallbackDisplayCategory = Category(
    id: 'other', name: '其他', icon: '📦', sortOrder: 999, isPreset: true);

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late final Future<Item?> _itemFuture;

  @override
  void initState() {
    super.initState();
    _itemFuture = AppScope.of(context).getItem(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return FutureBuilder<Item?>(
      future: _itemFuture,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (item == null) {
          return const Scaffold(
              body: EmptyState(
                  icon: Icons.error_outline,
                  title: '物品不存在',
                  subtitle: '该物品可能已被删除。'));
        }
        final category =
            store.categoryById(item.categoryId) ?? fallbackDisplayCategory;
        final display = ItemDisplay.fromItem(item: item, category: category);
        return Scaffold(
          appBar: AppBar(title: const Text('物品详情')),
          body: Center(
            child: ConstrainedBox(
              key: const ValueKey('item-detail-content'),
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ItemCard(display: display),
                  const SizedBox(height: 12),
                  DetailTile(label: '分类', value: display.categoryName),
                  DetailTile(label: '品牌', value: display.brandDisplay),
                  DetailTile(
                      label: '条码', value: emptyToFallback(item.barcode, '未填写')),
                  DetailTile(label: '存放位置', value: display.locationDisplay),
                  DetailTile(
                      label: '购买日期',
                      value: item.purchaseDate == null
                          ? '未记录'
                          : formatDate(item.purchaseDate!)),
                  DetailTile(label: '购入价格', value: display.priceText),
                  DetailTile(label: '保质期', value: display.expiryDateText),
                  DetailTile(label: '初始数量', value: '${item.initialQuantity}'),
                  DetailTile(label: '剩余数量', value: '${item.remainingQuantity}'),
                  DetailTile(label: '备注', value: display.notesDisplay),
                  const SizedBox(height: 12),
                  FutureBuilder<List<ConsumptionRecord>>(
                    future: store.getConsumptionRecords(item.id),
                    builder: (context, snapshot) {
                      final records =
                          snapshot.data ?? const <ConsumptionRecord>[];
                      if (records.isEmpty) {
                        return const DetailTile(label: '消耗记录', value: '暂无记录');
                      }
                      return SectionCard(
                        title: '消耗记录',
                        children: records
                            .map((record) => DetailTile(
                                  label: record.type.label,
                                  value:
                                      '${record.quantity} 件 · ${formatDate(record.consumedAt)}',
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AddItemPage(item: item)));
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: item.remainingQuantity <= 0
                            ? null
                            : () async {
                                await store.consumeOne(item.id);
                                if (context.mounted) Navigator.pop(context);
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('用掉一件'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: item.remainingQuantity <= 0
                            ? null
                            : () async {
                                final confirmed = await showConfirm(context,
                                    '消耗完成', '确认将「${item.name}」剩余数量全部消耗完成？');
                                if (!confirmed) return;
                                await store.consumeAll(item.id);
                                if (context.mounted) Navigator.pop(context);
                              },
                        icon: const Icon(Icons.done_all_outlined),
                        label: const Text('消耗完成'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final confirmed = await showConfirm(context, '删除物品',
                              '确定永久删除「${item.name}」吗？该操作不可恢复。');
                          if (!confirmed || !context.mounted) return;
                          final secondConfirmed = await showConfirm(
                              context, '二次确认', '真的永久删除这个物品吗？');
                          if (!secondConfirmed) return;
                          await store.deleteItem(item.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
