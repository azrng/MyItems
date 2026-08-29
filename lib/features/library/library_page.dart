import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../data/models/view_models.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';
import 'library_state.dart';
import 'library_widgets.dart';

/// 物品库（requirement.md §5.3，双列网格 + 筛选 + 批量操作）。
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 位置反查跳转：从存放位置页携带 locationId 进入（§5.8）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra;
      if (extra is String) {
        ref.read(selectedLocationProvider.notifier).state = extra;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final views = ref.watch(filteredLibraryViewsProvider);
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final locations =
        ref.watch(locationsProvider).value ?? const <StorageLocation>[];
    final inStock = ref.watch(activeViewsProvider).length;
    final spots = ref.watch(storageSpotCountProvider);
    final selecting = ref.watch(selectModeProvider);
    final selectedIds = ref.watch(selectedIdsProvider);
    final query = ref.watch(searchQueryProvider);

    // 筛选后的列表由 Provider 计算；此处兜底搜索框回显
    if (_searchCtrl.text != query) {
      _searchCtrl.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length));
    }

    // 多选模式的返回键拦截挂在 ShellScaffold（分支页 PopScope 拦不住系统返回）
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding, 12, AppTheme.pagePadding, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('物品库 📦',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  Text('$inStock 件 · $spots 个存放点',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: c.inkFaint)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.push('/categories'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: const Center(
                          child: Text('🗂', style: TextStyle(fontSize: 15))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 搜索 + 分类 chips + 位置/排序
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: '搜索名称 / 备注 / 存放位置…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 6),
            CategoryChips(categories: categories),
            const SizedBox(height: 6),
            const FilterRow(),
            const SizedBox(height: 4),
            // §5.3 操作提示文案
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('💡 点卡片可编辑详情，长按可多选批量调整',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: c.inkFaint)),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: selecting
                  ? _MultiSelectBody(views: views)
                  : views.isEmpty
                      ? EmptyState(
                          emoji: '🧺',
                          title: query.isEmpty ? '还没有物品' : '没有匹配的物品',
                          subtitle: query.isEmpty
                              ? '点击下方 ＋ 添加第一件，把囤货安排明白'
                              : '换个关键词或清除筛选试试',
                          actionLabel: query.isEmpty ? '去添加物品' : null,
                          onAction: query.isEmpty
                              ? () => context.push('/editor')
                              : null,
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              AppTheme.pagePadding,
                              4,
                              AppTheme.pagePadding,
                              120),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.80,
                          ),
                          itemCount: views.length,
                          itemBuilder: (context, i) => ItemCard(view: views[i]),
                        ),
            ),
          ],
        ),
      ),
      // 多选模式下常驻：未选中时也显示，提供「取消」退出多选的出口
      bottomNavigationBar: selecting
          ? _MultiActionBar(
              count: selectedIds.length,
              locations: locations,
              categories: categories,
            )
          : null,
    );
  }
}

/// 多选模式：底部批量操作条（§4.8 批量删除/移动位置/改分类）。
class _MultiActionBar extends ConsumerWidget {
  final int count;
  final List<StorageLocation> locations;
  final List<Category> categories;

  const _MultiActionBar({
    required this.count,
    required this.locations,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outline),
        ),
        child: count == 0
            ? Row(
                children: [
                  Text('点选物品加入批量',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _exitSelect(ref),
                    child: const Text('取消多选'),
                  ),
                ],
              )
            : Row(
                children: [
                  Text('已选 $count 件',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  // 取消/删除用图标钮：360dp 宽下文字按钮并排会横向溢出（真机实测 27px）
                  IconButton(
                    onPressed: () => _exitSelect(ref),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: '取消多选',
                  ),
                  TextButton(
                    onPressed: () => _move(context, ref),
                    child: const Text('移动位置'),
                  ),
                  TextButton(
                    onPressed: () => _changeCategory(context, ref),
                    child: const Text('改分类'),
                  ),
                  IconButton(
                    onPressed: () => _delete(context, ref),
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 20, color: scheme.error),
                    tooltip: '删除',
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final loc = await pickLocationSheet(context, locations);
    if (loc == null) return;
    final ids = ref.read(selectedIdsProvider).toList();
    final actions = ref.read(inventoryActionsProvider);
    for (final id in ids) {
      await actions.moveAllBatches(id, loc.id);
    }
    _exitSelect(ref);
    if (context.mounted) {
      showToast(context, '已移动 ${ids.length} 件到「${loc.name}」');
    }
  }

  Future<void> _changeCategory(BuildContext context, WidgetRef ref) async {
    final cat = await pickCategorySheet(context, categories);
    if (cat == null) return;
    final actions = ref.read(inventoryActionsProvider);
    for (final id in ref.read(selectedIdsProvider)) {
      await actions.changeCategory(id, cat.id);
    }
    _exitSelect(ref);
    if (context.mounted) showToast(context, '已改到「${cat.name}」');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    // 软删会让本页列表刷新，进异步前缓存 messenger 保证撤销条可见
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      title: '删除选中的 ${ref.read(selectedIdsProvider).length} 件物品？',
      content: '删除包含其批次与消耗记录，5 秒内可撤销。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    final ids = ref.read(selectedIdsProvider).toList();
    await ref.read(inventoryActionsProvider).deleteItems(ids);
    _exitSelect(ref);
    showUndoBarOn(messenger, '已移出 ${ids.length} 件物品',
        onUndo: () =>
            ref.read(inventoryActionsProvider).undoDeleteItems(ids));
  }

  void _exitSelect(WidgetRef ref) {
    ref.read(selectModeProvider.notifier).state = false;
    ref.read(selectedIdsProvider.notifier).state = {};
  }
}

class _MultiSelectBody extends ConsumerWidget {
  final List<LibraryItemView> views;
  const _MultiSelectBody({required this.views});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (views.isEmpty) {
      return const EmptyState(emoji: '🤷', title: '当前筛选下没有可选择的物品');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding, 4, AppTheme.pagePadding, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.80,
      ),
      itemCount: views.length,
      itemBuilder: (context, i) => ItemCard(view: views[i]),
    );
  }
}
