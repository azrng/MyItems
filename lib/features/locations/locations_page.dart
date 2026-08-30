import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../data/database/app_database.dart';
import '../../providers/actions.dart';
import '../../providers/core_providers.dart';
import '../../providers/inventory_providers.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';
import '../../widgets/meter.dart';
import '../../widgets/tag.dart';
import '../library/library_state.dart';

/// 存放位置（requirement.md §5.8）：区域分组 + 容量 + 临期计数 + 反查。
class LocationsPage extends ConsumerWidget {
  const LocationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider).value ?? const <StorageLocation>[];
    final views = ref.watch(activeViewsProvider);
    final expiring = ref.watch(expiringEntriesProvider);

    // 区域 → 位置分组
    final regions = <String, List<StorageLocation>>{};
    for (final l in locations.where((l) => l.isActive)) {
      regions.putIfAbsent(l.region, () => []).add(l);
    }

    int inStockOf(StorageLocation l) => views
        .where((v) => v.activeBatches.any((b) => b.locationId == l.id))
        .length;
    int expiringOf(StorageLocation l) => expiring
        .where((e) =>
            e.view.activeBatches.any((b) => b.locationId == l.id))
        .length;

    return SubPage(
      title: '存放位置',
      body: locations.isEmpty
          ? EmptyState(
              emoji: '📍',
              title: '还没有存放位置',
              subtitle: '建一个「冰箱冷藏室」，囤货就有地方查了',
              actionLabel: '＋ 新增位置',
              onAction: () => showLocationSheet(context, null),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding, 10, AppTheme.pagePadding, 120),
              children: [
                for (final region in regions.keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
                    child: Text(region,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                  for (final l in regions[region]!)
                    _LocationCard(
                      location: l,
                      inStock: inStockOf(l),
                      expiring: expiringOf(l),
                      onTap: () => showLocationSheet(context, l),
                      // 反查走 tab 切换 + 预设位置筛选；/library 是 ShellRoute
                      // 分支根，push 会再叠一层带底部导航的 Shell 导致界面异常
                      onView: () {
                        ref
                            .read(selectedLocationProvider.notifier)
                            .state = l.id;
                        context.go('/library');
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
      floatingActionButton: locations.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add_location',
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              onPressed: () => showLocationSheet(context, null),
              label: const Text('＋ 新增存放位置'),
            ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final StorageLocation location;
  final int inStock;
  final int expiring;
  final VoidCallback onTap;
  final VoidCallback onView;

  const _LocationCard({
    required this.location,
    required this.inStock,
    required this.expiring,
    required this.onTap,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final cap = location.capacity;
    final full = cap != null && inStock >= cap;
    final ratio = cap == null || cap <= 0 ? 0.0 : (inStock / cap).clamp(0.0, 1.0);

    return InkWell(
      // 不设长按：真机上长按反查会触发手势异常，反查入口收敛到「查看物品 ›」
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(location.icon ?? '📍', style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(location.name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                ),
                Text('$inStock 件在库',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800, color: c.inkFaint)),
                if (expiring > 0) ...[
                  const SizedBox(width: 6),
                  Tag('$expiring 件临期',
                      bg: scheme.error.withValues(alpha: 0.12), fg: scheme.error),
                ],
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: Meter(value: ratio)),
                const SizedBox(width: 10),
                Text(cap == null ? '不限' : '$inStock / $cap',
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800, color: c.inkFaint)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (full)
                  Text('别再囤啦，这里放满了 🈵',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer))
                else
                  const Spacer(),
                const Spacer(),
                InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(8),
                  child: Text('查看物品 ›',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 删除位置流程（§5.8）：无在库占用直接确认删除；
/// 有占用时必须先选承接位置，批次随删除一并移入并留移位痕。成功返回 true。
Future<bool> _deleteLocationFlow(BuildContext context, StorageLocation edit) async {
  final container = ProviderScope.containerOf(context);
  final actions = container.read(inventoryActionsProvider);
  final scheme = Theme.of(context).colorScheme;
  final batches = await container
      .read(inventoryRepositoryProvider)
      .getBatchesAtLocation(edit.id);
  if (!context.mounted) return false;
  final occupied = batches.where((b) => b.remainingQuantity > 0).length;

  if (occupied == 0) {
    final ok = await confirmDialog(
      context,
      title: '删除「${edit.name}」？',
      content: '删除后不可恢复，消耗记录保留。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return false;
    final result = await actions.deleteLocation(locationId: edit.id);
    return result is Success;
  }

  // 有在库批次占用：先选承接位置
  final others = (container.read(locationsProvider).value ?? const <StorageLocation>[])
      .where((l) => l.isActive && l.id != edit.id)
      .toList();
  if (others.isEmpty) {
    showToast(context, '该位置还有 $occupied 个批次存放，且没有其他位置可承接');
    return false;
  }
  String? targetId;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: scheme.surfaceContainerLowest,
        title: Text('删除「${edit.name}」？',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('这里还存放着 $occupied 个批次的物品，删除前先移到其他位置：',
                style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: targetId,
              decoration: const InputDecoration(labelText: '移到哪个位置'),
              items: [
                for (final l in others)
                  DropdownMenuItem(
                      value: l.id, child: Text('${l.icon ?? '📍'} ${l.name}')),
              ],
              onChanged: (v) => setState(() => targetId = v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError),
            onPressed: targetId == null ? null : () => Navigator.pop(ctx, true),
            child: const Text('删除并移动'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || targetId == null) return false;
  final result = await actions.deleteLocation(
      locationId: edit.id, moveToLocationId: targetId);
  return result is Success;
}

/// 新增 / 编辑位置弹层（§4.7 / §5.8）。
Future<void> showLocationSheet(BuildContext context, StorageLocation? edit) async {
  final nameCtrl = TextEditingController(text: edit?.name ?? '');
  final capCtrl = TextEditingController(text: '${edit?.capacity ?? 10}');
  String region = edit?.region ?? PresetLocations.presetRegions.first;
  String? customRegion;
  String icon = edit?.icon ?? '📦';
  bool unlimited = edit?.capacity == null;
  final form = GlobalKey<FormState>();

  await showAppSheet(
    context,
    child: StatefulBuilder(
      builder: (context, setState) {
        final scheme = Theme.of(context).colorScheme;
        return AppBottomSheet(
          title: edit == null ? '新增存放位置' : '编辑位置',
          body: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '位置名称'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
                ),
                const SizedBox(height: 12),
                const Text('所属区域',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in [...PresetLocations.presetRegions, '?custom'])
                      if (r == '?custom')
                        ChoiceChip(
                          label: Text(customRegion ?? '＋ 新区域…'),
                          selected: region == '?custom',
                          onSelected: (_) async {
                            final ctrl = TextEditingController(text: customRegion ?? '');
                            final name = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: scheme.surfaceContainerLowest,
                                title: const Text('新区域名称',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                                content: TextField(controller: ctrl, autofocus: true),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('取消')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, ctrl.text.trim()),
                                      child: const Text('确定')),
                                ],
                              ),
                            );
                            if (name != null && name.isNotEmpty) {
                              setState(() {
                                customRegion = name;
                                region = '?custom';
                              });
                            }
                          },
                        )
                      else
                        ChoiceChip(
                          label: Text(r),
                          selected: region == r,
                          onSelected: (_) => setState(() => region = r),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('图标',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in ['📦', '🧊', '❄️', '🗄️', '🧂', '🪞', '🧴', '👟', '🗃️', '🪟'])
                      InkWell(
                        onTap: () => setState(() => icon = e),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: icon == e
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: icon == e ? scheme.primary : scheme.outline),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 17)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchRow(
                  title: '不限容量',
                  subtitle: '关闭后可设容量上限，放满会软提醒',
                  value: unlimited,
                  onChanged: (v) => setState(() => unlimited = v),
                ),
                if (!unlimited) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: capCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '容量上限（默认建议 10 件）'),
                  ),
                  Text('放满后位置卡会提醒「别再囤啦」，不会阻止录入',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                ],
                if (edit != null) ...[
                  const SizedBox(height: 14),
                  Text('删除位置前会先处理存放中的物品；消耗记录保留',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                // 两个按钮都Expanded：真机（Android 8.1/Skia）下弹层 Row 内
                // 非 Expanded 按钮会收到无限宽约束导致整层布局崩溃
                if (edit != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(color: scheme.error.withValues(alpha: 0.5))),
                      onPressed: () async {
                        final deleted = await _deleteLocationFlow(context, edit);
                        if (!deleted || !context.mounted) return;
                        Navigator.pop(context);
                        showToast(context, '已删除「${edit.name}」');
                      },
                      child: const Text('删除'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (!(form.currentState?.validate() ?? false)) return;
                      final capacity =
                          unlimited ? null : (int.tryParse(capCtrl.text) ?? 10);
                      await ProviderScope.containerOf(context)
                          .read(inventoryActionsProvider)
                          .saveLocation(
                            id: edit?.id,
                            name: nameCtrl.text.trim(),
                            region: region == '?custom'
                                ? (customRegion ?? '自定义区域')
                                : region,
                            icon: icon,
                            capacity: capacity,
                            sortOrder: edit?.sortOrder ?? 99,
                            isActive: edit == null ? true : edit.isActive,
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
