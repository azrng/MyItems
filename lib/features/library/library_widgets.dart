import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/expiry_helper.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../data/database/app_database.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../data/models/view_models.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/meter.dart';
import '../../widgets/tag.dart';
import 'library_state.dart';

/// 物品库私有组件：双列卡片 / 分类 chips / 位置与排序筛选行 / 选择弹层。

class ItemCard extends ConsumerWidget {
  final LibraryItemView view;

  const ItemCard({super.key, required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final v = view;
    final selecting = ref.watch(selectModeProvider);
    final selected = ref.watch(selectedIdsProvider).contains(v.item.id);
    final consumable = v.item.isConsumable;
    final statusLabel =
        ExpiryHelper.statusLabel(v.status, v.effectiveExpiry, DateTime.now());

    return InkWell(
      onTap: () {
        if (selecting) {
          final ids = ref.read(selectedIdsProvider);
          ref.read(selectedIdsProvider.notifier).state = selected
              ? (ids..remove(v.item.id))
              : (ids..add(v.item.id));
        } else {
          context.push('/item/${v.item.id}');
        }
      },
      onLongPress: () {
        if (selecting) return;
        ref.read(selectModeProvider.notifier).state = true;
        ref.read(selectedIdsProvider.notifier).state = {v.item.id};
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selecting)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: selected ? scheme.primary : c.inkFaint,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(v.item.icon ?? '📦',
                        style: const TextStyle(fontSize: 16)),
                  ),
                Tag.fromStatus(v.status, statusLabel, scheme, c),
                const Spacer(),
                if (v.hasOpened)
                  Tag('已开封', bg: scheme.surfaceContainerHighest, fg: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            Text(v.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
              '${v.category?.name ?? '未分类'}'
              '${v.item.spec == null ? '' : ' · ${v.item.spec}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.inkFaint),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(Fmt.quantity(v.totalRemaining),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Text(
                  ' ${v.primaryBatch?.unit ?? '件'}'
                  '${v.percent < 100 ? ' · $percentText' : ''}',
                  style:
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.inkFaint),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Meter(value: v.percent / 100),
            const SizedBox(height: 8),
            if (v.lowRemaining)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tag('剩 $percentText · 余量低',
                    bg: scheme.primaryContainer, fg: scheme.onPrimaryContainer),
              ),
            if (consumable)
              Row(
                children: [
                  _StepBtn(
                    icon: Icons.remove_rounded,
                    onTap: () => _quickConsume(context, ref),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '点卡片可编辑详情',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600, color: c.inkFaint),
                    ),
                  ),
                  _StepBtn(
                    icon: Icons.add_rounded,
                    accent: true,
                    onTap: () => showQuickIntakeSheet(context, v),
                  ),
                ],
              )
            else
              Text('耐用品 · 不参与消耗',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: c.inkFaint)),
          ],
        ),
      ),
    );
  }

  String get percentText => '$appendixPercent';
  int get appendixPercent => view.percent;

  Future<void> _quickConsume(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(inventoryActionsProvider);
    final unit = view.primaryBatch?.unit ?? '件';
    final result = await actions.consume(
        itemId: view.item.id, quantity: 1, source: LogSources.quickConsume);
    if (result is Success<String?> && context.mounted) {
      showToast(context, '−1 $unit 已记录');
      final logId = result.data;
      if (logId != null) {
        showUndoBar(context, '已消耗 1 $unit',
            onUndo: () => actions.undoConsume(logId));
      }
    } else if (result is Failure<String?> && context.mounted) {
      showToast(context, result.message);
    }
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool accent;
  final VoidCallback onTap;

  const _StepBtn({required this.icon, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 30,
        decoration: BoxDecoration(
          color: accent ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 17,
            color: accent ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
      ),
    );
  }
}

/// 分类 chips 带计数（全部 / 🥕食品38 …）。
class CategoryChips extends ConsumerWidget {
  final List<Category> categories;

  const CategoryChips({super.key, required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(activeViewsProvider);
    final selected = ref.watch(selectedCategoryProvider);
    final all = [null, ...categories.map((e) => e.id)];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = all[i];
          final cat = id == null ? null : categories.firstWhere((c) => c.id == id);
          final count = id == null
              ? views.length
              : views.where((v) => v.item.categoryId == id).length;
          final isSel = selected == id;
          final scheme = Theme.of(context).colorScheme;
          return InkWell(
            onTap: () => ref.read(selectedCategoryProvider.notifier).state = id,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? scheme.onSurface : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isSel ? scheme.onSurface : scheme.outline),
              ),
              child: Text(
                id == null
                    ? '全部 $count'
                    : '${cat?.icon ?? ''}${cat?.name ?? ''} $count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSel ? scheme.surfaceContainerLowest : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 位置筛选 + 排序切换行。
class FilterRow extends ConsumerWidget {
  const FilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final locations = ref.watch(locationsProvider).value ?? const <StorageLocation>[];
    final locationId = ref.watch(selectedLocationProvider);
    final sortMode = ref.watch(sortModeProvider);
    final locName = locationId == null
        ? null
        : locations.where((l) => l.id == locationId).firstOrNull?.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              final picked = await pickLocationSheet(context, locations);
              if (picked != null) {
                ref.read(selectedLocationProvider.notifier).state = picked.id;
              }
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: locationId == null ? scheme.outline : scheme.primary),
              ),
              child: Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(locName ?? '全部位置',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: locationId == null
                              ? scheme.onSurfaceVariant
                              : scheme.onPrimaryContainer)),
                  if (locationId != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () =>
                          ref.read(selectedLocationProvider.notifier).state = null,
                      child: Icon(Icons.close_rounded,
                          size: 14, color: scheme.onPrimaryContainer),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => ref.read(sortModeProvider.notifier).state =
                sortMode == 0 ? 1 : 0,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.outline),
              ),
              child: Row(
                children: [
                  Icon(sortMode == 0
                      ? Icons.schedule_rounded
                      : Icons.add_circle_outline_rounded,
                      size: 14, color: c.inkFaint),
                  const SizedBox(width: 4),
                  Text(sortMode == 0 ? '到期时间 ↑' : '添加时间 ↓',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 位置单选弹层（返回选中的位置对象；含「全部位置」清空入口在调用方处理）。
Future<StorageLocation?> pickLocationSheet(
    BuildContext context, List<StorageLocation> locations) {
  return showAppSheet<StorageLocation>(
    context,
    child: AppBottomSheet(
      title: '选择存放位置',
      body: Column(
        children: [
          for (final l in locations.where((l) => l.isActive))
            ListTile(
              leading: Text(l.icon ?? '📍', style: const TextStyle(fontSize: 18)),
              title: Text(l.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(l.region,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, l),
            ),
        ],
      ),
    ),
  );
}

/// 分类单选弹层（批量改分类用）。
Future<Category?> pickCategorySheet(
    BuildContext context, List<Category> categories) {
  return showAppSheet<Category>(
    context,
    child: AppBottomSheet(
      title: '改到哪个分类',
      body: Column(
        children: [
          for (final cat in categories)
            ListTile(
              leading: Text(cat.icon ?? '🗂', style: const TextStyle(fontSize: 18)),
              title: Text(cat.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, cat),
            ),
        ],
      ),
    ),
  );
}

/// 「＋」快捷再入库面板：预填上次规格，确认后新建批次（§4.3 / §4.6）。
Future<void> showQuickIntakeSheet(BuildContext context, LibraryItemView v) async {
  final primary = v.primaryBatch;
  final qtyCtrl = TextEditingController(text: Fmt.quantity(primary?.initialQuantity ?? 1));
  DateTime? expiry = primary?.expiryDate;
  final form = GlobalKey<FormState>();

  await showAppSheet(
    context,
    child: AppBottomSheet(
      title: '再次入库 · ${v.item.name}',
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预填上次规格，保存为新批次',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).extension<AppColors>()!.inkFaint)),
            const SizedBox(height: 12),
            TextFormField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '数量（${primary?.unit ?? '件'}）',
              ),
              validator: (s) =>
                  (double.tryParse(s ?? '') ?? 0) <= 0 ? '请输入大于 0 的数量' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('到期日期',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: expiry ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) expiry = d;
                  },
                  child: Text(expiry == null ? '沿用上次（可改）' : Fmt.date(expiry)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            final container = ProviderScope.containerOf(context);
            final actions = container.read(inventoryActionsProvider);
            final result = await actions.saveIntake(
              existingItemId: v.item.id,
              name: v.item.name,
              categoryId: v.item.categoryId,
              icon: v.item.icon,
              isConsumable: v.item.isConsumable,
              reminderEnabled: v.item.reminderEnabled,
              locationId: (primary?.locationId ?? v.item.lastLocationId ?? ''),
              quantity: double.parse(qtyCtrl.text),
              unit: primary?.unit ?? '件',
              expiryDate: expiry,
              spec: v.item.spec,
            );
            if (result is Success && context.mounted) {
              Navigator.pop(context);
              showToast(context, '已再入库，账记上了 🧾');
            }
          },
          child: const Text('确认入库'),
        ),
      ],
    ),
  );
}
