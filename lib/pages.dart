import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'main.dart';
import 'models.dart';
import 'models.dart' as my;

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final pages = [
      const HomePage(),
      const ExpiringPage(),
      const LibraryPage(),
      const CategoryPage(),
    ];

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              if (_index == 0)
                IconButton(
                  tooltip: '添加物品',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddItemPage())),
                ),
            ],
          ),
          drawer: AppDrawer(onNavigate: (target) {
            Navigator.pop(context);
            if (target == DrawerTarget.add) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddItemPage()));
            } else if (target == DrawerTarget.storage) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StoragePage()));
            } else if (target == DrawerTarget.locations) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LocationPage()));
            } else if (target == DrawerTarget.archived) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ArchivedItemsPage()));
            } else if (target == DrawerTarget.consumptionRecords) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ConsumptionRecordsPage()));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutPage()));
            }
          }),
          body: Stack(
            children: [
              pages[_index],
              if (store.isLoading) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '主页'),
              NavigationDestination(
                  icon: Icon(Icons.notifications_none),
                  selectedIcon: Icon(Icons.notifications),
                  label: '临期'),
              NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: '物品库'),
              NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: '分类'),
            ],
          ),
          floatingActionButton: _index == 2
              ? FloatingActionButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddItemPage())),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  String get _title => switch (_index) {
        0 => '我的物品',
        1 => '临期提醒',
        2 => '物品库',
        _ => '分类管理',
      };
}

enum DrawerTarget { add, storage, locations, archived, consumptionRecords, about }

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onNavigate});

  final ValueChanged<DrawerTarget> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).colorScheme.primary,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📦 我的物品',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('物品管理助手', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('添加'),
              onTap: () => onNavigate(DrawerTarget.add),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('存储管理'),
              onTap: () => onNavigate(DrawerTarget.storage),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('存放位置'),
              onTap: () => onNavigate(DrawerTarget.locations),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('耗尽归档'),
              onTap: () => onNavigate(DrawerTarget.archived),
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('消耗记录'),
              onTap: () => onNavigate(DrawerTarget.consumptionRecords),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              onTap: () => onNavigate(DrawerTarget.about),
            ),
          ],
        ),
      ),
    );
  }
}

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
                    child: ItemCard(display: item),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class ExpiryGroupSection extends StatelessWidget {
  const ExpiryGroupSection({super.key, required this.group});

  final ExpiryGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('${group.icon} ${group.headerText}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ...group.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ItemCard(display: item),
              )),
        ],
      ),
    );
  }
}

class ExpiringPage extends StatelessWidget {
  const ExpiringPage({super.key});

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
                hint: '搜索临期或已过期物品',
                initialValue: store.expirySearch,
                onChanged: store.setExpirySearch,
              ),
              const SizedBox(height: 12),
              if (store.errorMessage != null)
                ErrorBanner(message: store.errorMessage!),
              if (store.expiryGroups.every((group) => group.items.isEmpty))
                const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: '暂无临期提醒',
                    subtitle: '已过期和 7 天内到期的物品会显示在这里。'),
              ...store.expiryGroups
                  .map((group) => ExpiryGroupSection(group: group)),
            ],
          ),
        );
      },
    );
  }
}

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
                            context,
                            '删除物品',
                            '确定永久删除「${item.name}」吗？该操作不可恢复。');
                        if (!confirmed) return false;
                        if (!context.mounted) return false;
                        final secondConfirmed = await showConfirm(
                            context, '二次确认', '真的永久删除这个物品吗？');
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
                      child: ItemCard(display: item),
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
              value: '¥${statistics.totalSpent.toStringAsFixed(1)}',
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

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.display});

  final ItemDisplay display;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ItemDetailPage(itemId: display.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(display.categoryIcon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(display.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${display.brandDisplay} · ${display.categoryName} · ${display.locationDisplay}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          display.item.expiryDate == null
                              ? display.holdingText
                              : '保质 ${display.expiryDateText}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          display.priceText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          display.stockText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (display.dailyCostText.isNotEmpty)
                          Text(
                            display.dailyCostText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(display: display),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.display});

  final ItemDisplay display;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground, text) = switch (display.expiryStatus) {
      ExpiryStatus.expired => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          display.expiryStatusText
        ),
      ExpiryStatus.expiring => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          display.expiryStatusText
        ),
      ExpiryStatus.safe => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          '安全'
        ),
      ExpiryStatus.noExpiry => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
          '无期限'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              color: foreground, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.delete_outline, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ItemDetailPage extends StatelessWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return FutureBuilder<Item?>(
      future: store.getItem(itemId),
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
          body: ListView(
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
                  final records = snapshot.data ?? const <ConsumptionRecord>[];
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
                          final secondConfirmed =
                              await showConfirm(context, '二次确认', '真的永久删除这个物品吗？');
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

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key, this.item});

  final Item? item;

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  late final ItemFormData _form = widget.item == null
      ? ItemFormData()
      : ItemFormData.fromItem(widget.item!);
  late final TextEditingController _name =
      TextEditingController(text: _form.name);
  late final TextEditingController _brand =
      TextEditingController(text: _form.brand);
  late final TextEditingController _price =
      TextEditingController(text: _form.purchasePrice?.toString() ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: _form.notes);

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final isEditing = widget.item != null;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        _form.categoryId ??=
            store.categories.isEmpty ? null : store.categories.first.id;
        return Scaffold(
          appBar: AppBar(title: Text(isEditing ? '编辑物品' : '添加物品')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              SectionCard(
                title: '基础信息',
                children: [
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '物品名称 *')),
                  DropdownButtonFormField<String>(
                    initialValue: _form.categoryId,
                    decoration: const InputDecoration(labelText: '分类 *'),
                    items: store.categories
                        .map<DropdownMenuItem<String>>(
                            (c) => DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text('${c.icon ?? '📦'} ${c.name}'),
                                ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _form.categoryId = value),
                  ),
                  TextField(
                      controller: _brand,
                      decoration: const InputDecoration(labelText: '品牌')),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '批次信息',
                children: [
                  TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '单价')),
                  DropdownButtonFormField<String>(
                    initialValue: _form.location?.trim().isEmpty ?? true
                        ? null
                        : _form.location,
                    decoration: const InputDecoration(labelText: '存放位置'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('未选择'),
                      ),
                      ...store.locations.map(
                        (location) => DropdownMenuItem<String>(
                          value: location.name,
                          child: Text(location.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _form.location = value ?? ''),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('购买日期'),
                    subtitle: Text(_form.purchaseDate == null
                        ? '未记录'
                        : formatDate(_form.purchaseDate!)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _form.purchaseDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _form.purchaseDate = picked);
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('无保质期'),
                    value: _form.noExpiry,
                    onChanged: (value) =>
                        setState(() => _form.noExpiry = value),
                  ),
                  if (!_form.noExpiry)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('保质期'),
                      subtitle: Text(formatDate(_form.expiryDate!)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _form.expiryDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _form.expiryDate = picked);
                        }
                      },
                    ),
                  StepperRow(
                    label: '初始数量',
                    value: _form.quantity,
                    onChanged: (value) =>
                        setState(() => _form.quantity = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('记录日均成本'),
                    value: _form.trackDailyCost,
                    onChanged: (value) =>
                        setState(() => _form.trackDailyCost = value),
                  ),
                  TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '备注')),
                ],
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                try {
                  _form.name = _name.text;
                  _form.brand = _brand.text;
                  _form.purchasePrice = double.tryParse(_price.text);
                  _form.notes = _notes.text;
                  await store.saveItemFromForm(_form);
                  if (context.mounted) Navigator.pop(context);
                } catch (error) {
                  if (context.mounted) showSnack(context, error.toString());
                }
              },
              child: Text(isEditing ? '保存修改' : '保存'),
            ),
          ),
        );
      },
    );
  }
}

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _name = TextEditingController();
  String _selectedIcon = defaultCategoryIcon;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: '新增分类',
              children: [
                Row(
                  children: [
                    IconPreviewButton(
                      icon: _selectedIcon,
                      onPressed: () async {
                        final icon = await showCategoryIconPicker(
                            context, _selectedIcon);
                        if (icon != null) setState(() => _selectedIcon = icon);
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: _name,
                            decoration:
                                const InputDecoration(labelText: '分类名称'))),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () async {
                        try {
                          await store.addCategory(_name.text, _selectedIcon);
                          _name.clear();
                          setState(() => _selectedIcon = defaultCategoryIcon);
                        } catch (error) {
                          if (context.mounted) {
                            showSnack(context, error.toString());
                          }
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: store.categories.length,
              onReorder: (oldIndex, newIndex) async {
                try {
                  await store.reorderCategory(oldIndex, newIndex);
                } catch (error) {
                  if (context.mounted) showSnack(context, error.toString());
                }
              },
              itemBuilder: (context, index) {
                final category = store.categories[index];
                var tile = Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(category.icon ?? defaultCategoryIcon)),
                    title: Text(category.name),
                    subtitle: Text(category.isPreset ? '预置分类' : '自定义分类'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (category.isPreset) const Icon(Icons.lock_outline),
                        IconButton(
                          tooltip: '编辑分类',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await showCategoryEditDialog(
                              context,
                              category,
                              store,
                            );
                          },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                if (!category.isPreset) {
                  tile = Card(
                    child: Dismissible(
                      key: ValueKey('category-dismiss-${category.id}'),
                      direction: DismissDirection.endToStart,
                      background: const SizedBox.shrink(),
                      secondaryBackground:
                          const SwipeDeleteBackground(label: '删除'),
                      confirmDismiss: (_) async {
                        final confirmed = await showConfirm(
                            context, '删除分类', '确定删除「${category.name}」吗？');
                        if (!confirmed) return false;
                        try {
                          await store.deleteCategory(category);
                        } catch (error) {
                          if (context.mounted) {
                            showSnack(context, error.toString());
                          }
                        }
                        return false;
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(category.icon ?? defaultCategoryIcon)),
                        title: Text(category.name),
                        subtitle: const Text('自定义分类'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '编辑分类',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                await showCategoryEditDialog(
                                  context,
                                  category,
                                  store,
                                );
                              },
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Padding(
                  key: ValueKey('category-row-${category.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: tile,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class IconPreviewButton extends StatelessWidget {
  const IconPreviewButton(
      {super.key, required this.icon, required this.onPressed});

  final String icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('存放位置')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: '新增位置',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: '位置名称'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () async {
                          try {
                            await store.addLocation(_name.text);
                            _name.clear();
                          } catch (error) {
                            if (context.mounted) {
                              showSnack(context, error.toString());
                            }
                          }
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...store.locations.map(
                (location) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(location.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '重命名',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              await showLocationEditDialog(
                                context,
                                location,
                                store,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final confirmed = await showConfirm(
                                  context, '删除位置', '确定删除「${location.name}」吗？');
                              if (!confirmed) return;
                              await store.deleteLocation(location);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
                    child: ItemCard(display: item),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class ConsumptionRecordsPage extends StatelessWidget {
  const ConsumptionRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('消耗记录')),
      body: FutureBuilder<List<ConsumptionRecordDisplay>>(
        future: store.getConsumptionRecordDisplays(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <ConsumptionRecordDisplay>[];
          if (records.isEmpty) {
            return const EmptyState(
              icon: Icons.history_outlined,
              title: '暂无消耗记录',
              subtitle: '用掉一件或消耗完成后会记录在这里。',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final display = records[index];
              final record = display.record;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(record.type.label),
                  subtitle: Text(display.itemName),
                  trailing: Text('${record.quantity} 件\n${formatDate(record.consumedAt)}',
                      textAlign: TextAlign.right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StoragePageState extends State<StoragePage> {
  String? _selectedBackupPath;
  String? _selectedImportPath;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('存储管理')),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                        child: Text('💾', style: TextStyle(fontSize: 52))),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('管理你的数据，随时导入导出',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ),
                    const SizedBox(height: 18),
                    SectionCard(
                      title: '完整备份与恢复',
                      children: [
                        StorageActionTile(
                          icon: '📤',
                          title: '导出完整备份',
                          subtitle: '一键导出分类、存放位置、物品、消耗记录和设置',
                          buttonText: '导出备份',
                          onPressed: () async {
                            try {
                              final backup = await store.buildBackupFile();
                              await const MethodChannel(
                                      'my_items/system')
                                  .invokeMethod<String>(
                                'saveBackupToDownloads',
                                {
                                  'fileName': backup.$1,
                                  'content': backup.$2,
                                },
                              );
                              if (context.mounted) {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('导出成功'),
                                    content: const Text(
                                      '备份已保存到：\nDownload/MyItems\n\n'
                                      '请在系统文件管理器的「下载」中查找。',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('知道了'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '导出备份失败：$error');
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['json'],
                              dialogTitle: '选择我的物品备份文件',
                            );
                            final path = result?.files.single.path;
                            if (path == null || path.trim().isEmpty) return;
                            setState(() => _selectedBackupPath = path);
                          },
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('选择备份文件'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedBackupPath ?? '尚未选择备份文件',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        StorageActionTile(
                          icon: '📥',
                          title: '恢复完整备份',
                          subtitle: '将备份恢复到当前手机，现有数据会被备份内容覆盖',
                          buttonText: '恢复备份',
                          onPressed: () async {
                            final path = _selectedBackupPath?.trim() ?? '';
                            if (path.isEmpty) {
                              showSnack(context, '请先选择备份文件');
                              return;
                            }
                            final confirmed = await showConfirm(
                                context, '恢复备份', '将用备份文件覆盖当前手机数据，确认继续？');
                            if (!confirmed) return;
                            if (!context.mounted) return;
                            final secondConfirmed = await showConfirm(
                                context, '二次确认', '恢复后当前数据会被替换，真的继续吗？');
                            if (!secondConfirmed) return;
                            try {
                              final result = await store.importBackup(path);
                              if (context.mounted) {
                                showSnack(context,
                                    '恢复完成：成功 ${result.$1} 条，失败 ${result.$2} 条');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '恢复失败：$error');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'CSV 兼容工具',
                      children: [
                        StorageActionTile(
                          icon: '📄',
                          title: '导出 CSV',
                          subtitle: '导出物品和分类表格，适合人工查看，不作为完整迁移备份',
                          buttonText: '导出 CSV',
                          onPressed: () async {
                            try {
                              final path = await store.exportToCsv();
                              if (context.mounted) {
                                showSnack(context, '已导出：$path');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '导出 CSV 失败：$error');
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['csv'],
                              dialogTitle: '选择 CSV 文件',
                            );
                            final path = result?.files.single.path;
                            if (path == null || path.trim().isEmpty) return;
                            setState(() => _selectedImportPath = path);
                          },
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('选择 CSV 文件'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedImportPath ?? '尚未选择 CSV 文件',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        StorageActionTile(
                          icon: '📥',
                          title: '导入 CSV',
                          subtitle: '兼容导入旧 CSV 数据，不包含消耗记录和设置',
                          buttonText: '导入 CSV',
                          onPressed: () async {
                            final path = _selectedImportPath?.trim() ?? '';
                            if (path.isEmpty) {
                              showSnack(context, '请先选择 CSV 文件');
                              return;
                            }
                            final confirmed = await showConfirm(
                                context, '导入 CSV', '将从 CSV 文件导入物品数据，确认继续？');
                            if (!confirmed) return;
                            try {
                              final result = await store.importFromCsv(path);
                              if (context.mounted) {
                                showSnack(context,
                                    '导入完成：成功 ${result.$1} 条，失败 ${result.$2} 条');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '导入 CSV 失败：$error');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: '危险操作',
                      children: [
                        StorageActionTile(
                          icon: '🗑️',
                          title: '清空所有数据',
                          subtitle: '删除所有物品和自定义分类，此操作不可恢复',
                          buttonText: '清空数据',
                          danger: true,
                          onPressed: () async {
                            final confirmed = await showConfirm(
                                context, '清空数据', '将删除所有物品数据，此操作不可恢复。确定继续？');
                            if (!confirmed) return;
                            if (!context.mounted) return;
                            final secondConfirmed = await showConfirm(
                                context, '二次确认', '真的要清空所有数据吗？');
                            if (!secondConfirmed) return;
                            try {
                              await store.clearAllData();
                              if (context.mounted) {
                                showSnack(context, '所有数据已清空');
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showSnack(context, '清空失败：$error');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (store.isLoading) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        );
      },
    );
  }
}

class StorageActionTile extends StatelessWidget {
  const StorageActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    this.danger = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = danger
        ? colorScheme.error
        : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: danger ? color : null)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: danger
                                    ? colorScheme.onErrorContainer
                                    : colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          danger
              ? FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: onPressed,
                  child: Text(buttonText),
                )
              : FilledButton.tonal(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
        ],
      ),
    );
  }
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Center(child: Text('📦', style: TextStyle(fontSize: 54))),
              const SizedBox(height: 8),
              const Center(
                  child: Text('我的物品',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              const Center(child: Text('版本 1.0.0')),
              const SizedBox(height: 18),
              const SectionCard(
                title: '简介',
                children: [
                  Text('个人/家庭自用的物品管理 App，用于跟踪保质期、存放位置、购买价格和分类信息。'),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '信息',
                children: const [
                  DetailTile(label: '作者', value: 'azrng'),
                  ProjectLinkTile(
                    label: '项目地址',
                    value: 'github.com/azrng/MyItems',
                    url: 'https://github.com/azrng/MyItems',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '主题模式',
                children: [
                  SegmentedButton<ThemePreference>(
                    segments: ThemePreference.values
                        .map((preference) => ButtonSegment<ThemePreference>(
                              value: preference,
                              label: Text(preference.label),
                            ))
                        .toList(),
                    selected: {store.themePreference},
                    onSelectionChanged: (values) {
                      store.setThemePreference(values.first);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProjectLinkTile extends StatelessWidget {
  const ProjectLinkTile({
    super.key,
    required this.label,
    required this.value,
    required this.url,
  });

  final String label;
  final String value;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          await const MethodChannel('my_items/system').invokeMethod<void>(
            'openUrl',
            {'url': url},
          );
        } catch (error) {
          if (context.mounted) {
            showSnack(context, '无法打开项目地址：$error');
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }
}

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
  });

  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    this.label = '数量',
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton.outlined(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$value', style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.outlined(
            onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add)),
      ],
    );
  }
}

class DetailTile extends StatelessWidget {
  const DetailTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 84,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message,
          style: TextStyle(color: colorScheme.onErrorContainer)),
    );
  }
}

Future<bool> showConfirm(
    BuildContext context, String title, String content) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定')),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showCategoryEditDialog(
    BuildContext context, Category category, AppStore store) async {
  final controller = TextEditingController(text: category.name);
  var selectedIcon = category.icon ?? defaultCategoryIcon;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconPreviewButton(
                icon: selectedIcon,
                onPressed: () async {
                  final icon =
                      await showCategoryIconPicker(context, selectedIcon);
                  if (icon != null) setState(() => selectedIcon = icon);
                },
              ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '分类名称'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                await store.renameCategory(
                    category, controller.text, selectedIcon);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
}

Future<void> showLocationEditDialog(
    BuildContext context, StorageLocation location, AppStore store) async {
  final controller = TextEditingController(text: location.name);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('重命名位置'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: '位置名称'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            await store.renameLocation(location, controller.text);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
}

Future<String?> showCategoryIconPicker(
    BuildContext context, String selectedIcon) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择分类图标',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 232,
              child: GridView.builder(
                itemCount: categoryIconOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final icon = categoryIconOptions[index];
                  final selected = icon == selectedIcon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

const defaultCategoryIcon = '🏷️';

const categoryIconOptions = [
  '🍔',
  '🥛',
  '🍎',
  '💄',
  '🧴',
  '💊',
  '🧻',
  '🧼',
  '💻',
  '🔌',
  '🏠',
  '👕',
  '🎒',
  '📚',
  '⚽',
  '🎁',
  '🐱',
  '🚗',
  '🧰',
  defaultCategoryIcon,
];

const fallbackDisplayCategory = my.Category(
    id: 'other', name: '其他', icon: '📦', sortOrder: 999, isPreset: true);
