import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../core/utils/result.dart';
import '../../providers/actions.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_providers.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';

/// 分类管理（requirement.md §5.7）：8 预置 + 自定义 CRUD + 拖拽排序。
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return SubPage(
      title: '物品分类',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(74, 40),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () => showCategorySheet(context, null),
            child: const Text('＋ 新建'),
          ),
        ),
      ],
      body: categories.isEmpty
          ? const EmptyState(emoji: '🗂', title: '还没有分类')
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding, 10, AppTheme.pagePadding, 120),
              itemCount: categories.length,
              onReorder: (oldIndex, newIndex) async {
                final list = [...categories];
                if (newIndex > oldIndex) newIndex -= 1;
                final moved = list.removeAt(oldIndex);
                list.insert(newIndex, moved);
                await ref
                    .read(inventoryActionsProvider)
                    .saveCategoryOrder(list);
              },
              proxyDecorator: (child, index, animation) => ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.03).animate(animation),
                child: Material(
                  color: Colors.transparent,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(20),
                  child: child,
                ),
              ),
              itemBuilder: (context, i) {
                final cat = categories[i];
                return _CategoryRow(
                  key: ValueKey(cat.id),
                  category: cat,
                  onTap: () => showCategorySheet(context, cat),
                );
              },
            ),
    );
  }
}

class _CategoryRow extends ConsumerStatefulWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryRow({super.key, required this.category, required this.onTap});

  @override
  ConsumerState<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends ConsumerState<_CategoryRow> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CategoryRow old) {
    super.didUpdateWidget(old);
    if (old.category.id != widget.category.id) _load();
  }

  Future<void> _load() async {
    // ConsumerState 自带 ref；initState 期间禁止 containerOf（会建立 inherited 依赖导致构建中断）
    final repo = ref.read(inventoryRepositoryProvider);
    final n = await repo.countItemsOfCategory(widget.category.id);
    if (mounted) setState(() => _count = n);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final color = categoryColor(c, widget.category.colorKey);
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.drag_indicator_rounded,
                    size: 18, color: c.inkFaint),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.soft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(widget.category.icon ?? '🗂',
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.category.name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                  if (widget.category.description != null)
                    Text(widget.category.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: c.inkFaint)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$_count 件',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: c.inkFaint)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 新建 / 编辑分类弹层（§4.7 / §5.7）。
Future<void> showCategorySheet(BuildContext context, Category? edit) async {
  final nameCtrl = TextEditingController(text: edit?.name ?? '');
  String icon = edit?.icon ?? '📦';
  String colorKey = edit?.colorKey ?? 'accent';
  final form = GlobalKey<FormState>();

  await showAppSheet(
    context,
    child: StatefulBuilder(
      builder: (context, setState) {
        final scheme = Theme.of(context).colorScheme;
        final c = Theme.of(context).extension<AppColors>()!;
        return AppBottomSheet(
          title: edit == null ? '新建分类' : '编辑分类',
          body: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '分类名称'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
                ),
                const SizedBox(height: 14),
                const Text('图标（12 选 1）',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in ['🥕', '🧹', '🍳', '💊', '💄', '🧃', '🔌', '📦', '🧴', '🧺', '🕯️', '🪴'])
                      InkWell(
                        onTap: () => setState(() => icon = e),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: icon == e
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: icon == e
                                    ? scheme.primary
                                    : scheme.outline),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('颜色标记（用于筛选与图表）',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final k in CategoryColorKeys.all) ...[
                      InkWell(
                        onTap: () => setState(() => colorKey = k),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: categoryColor(c, k).strong,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: colorKey == k
                                    ? scheme.onSurface
                                    : Colors.transparent,
                                width: 2.4),
                          ),
                        ),
                      ),
                      if (k != CategoryColorKeys.all.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
                if (edit != null && edit.isPreset) ...[
                  const SizedBox(height: 14),
                  Text('预置分类不可删除，可改名改色',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: c.inkFaint)),
                ],
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                if (edit != null && !edit.isPreset)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error.withValues(alpha: 0.5))),
                    onPressed: () async {
                      final actions = ProviderScope.containerOf(context)
                          .read(inventoryActionsProvider);
                      final ok = await confirmDialog(context,
                          title: '删除「${edit.name}」？',
                          content: '仅能删除没有在库物品的分类。',
                          confirmText: '删除',
                          danger: true);
                      if (!ok || !context.mounted) return;
                      final result = await actions.deleteCategory(edit.id);
                      if (!context.mounted) return;
                      if (result is Success) {
                        Navigator.pop(context);
                        showToast(context, '已删除');
                      } else {
                        showToast(context, (result as Failure).message);
                      }
                    },
                    child: const Text('删除'),
                  ),
                if (edit != null && !edit.isPreset) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (!(form.currentState?.validate() ?? false)) return;
                      await ProviderScope.containerOf(context)
                          .read(inventoryActionsProvider)
                          .saveCategory(
                            id: edit?.id,
                            name: nameCtrl.text.trim(),
                            icon: icon,
                            colorKey: colorKey,
                            description: edit?.description,
                            sortOrder: edit?.sortOrder ?? 99,
                            isPreset: edit?.isPreset ?? false,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        showToast(context, edit == null ? '已创建' : '已保存');
                      }
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
