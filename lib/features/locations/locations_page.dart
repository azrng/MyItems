import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';
import '../../widgets/meter.dart';
import '../../widgets/tag.dart';

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
                      onView: () => context.push('/library', extra: l.id),
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
      onTap: onTap,
      onLongPress: onView,
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
                  Text('删除位置即停用，不影响已有物品的历史位置',
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
                if (edit != null)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error.withValues(alpha: 0.5))),
                    onPressed: () async {
                      final actions = ProviderScope.containerOf(context)
                          .read(inventoryActionsProvider);
                      final ok = await confirmDialog(context,
                          title: '停用「${edit.name}」？',
                          content: '停用后不再出现在选择列表，历史记录保留。',
                          confirmText: '停用',
                          danger: true);
                      if (!ok || !context.mounted) return;
                      await actions.deactivateLocation(edit.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      showToast(context, '已停用');
                    },
                    child: const Text('停用'),
                  ),
                if (edit != null) const SizedBox(width: 10),
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
