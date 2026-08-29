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
import '../library/library_widgets.dart' show showQuickIntakeSheet;
import 'detail_sheets.dart';

/// 物品详情页（requirement.md §5.13）：同一物品多批次并存的默认落点。
class ItemDetailPage extends ConsumerWidget {
  final String itemId;

  const ItemDetailPage({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final views = ref.watch(libraryViewsProvider);
    final v = views.where((e) => e.item.id == itemId).firstOrNull;
    // 无在库批次时 view 为 null（物品库/首页不展示），标题与编辑仍需物品主档
    final item = v?.item ??
        (ref.watch(itemsProvider).value ?? const <Item>[])
            .where((e) => e.id == itemId)
            .firstOrNull;
    final batches = ref.watch(batchesProvider).value ?? const <Batch>[];
    final locations =
        ref.watch(locationsProvider).value ?? const <StorageLocation>[];
    final itemBatches = batches.where((b) => b.itemId == itemId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final now = DateTime.now();
    final expiredDays = v?.effectiveExpiry == null
        ? 0
        : -ExpiryHelper.daysUntil(v!.effectiveExpiry, now);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding, 8, AppTheme.pagePadding, 140),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item?.name ?? '物品详情',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 40),
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                  ),
                  onPressed: () => context.push('/editor/$itemId'),
                  child: const Text('编辑'),
                ),
              ],
            ),
            if (v != null) ...[
              const SizedBox(height: 14),
              _header(v, c, scheme, now),
              if (expiredDays > 3 && !v.item.isArchived)
                _expiredGuide(context, v),
              const SizedBox(height: 18),
              Text('批次列表',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              for (final b in itemBatches)
                BatchCard(
                  batch: b,
                  view: v,
                  locationName: locations
                      .where((l) => l.id == b.locationId)
                      .firstOrNull
                      ?.name,
                ),
              const SizedBox(height: 14),
              FilledButton(
                // 再次入库：新建批次（挂批次会自动恢复在库状态），而非编辑主档
                onPressed: item == null
                    ? null
                    : () => showQuickIntakeSheet(context,
                        item: item, primary: v.primaryBatch),
                child: const Text('＋ 再次入库'),
              ),
            ] else ...[
              // 空态兜底（§5.13：无在库批次）
              Column(
                children: [
                  const SizedBox(height: 60),
                  const Text('🌫', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 10),
                  Text(
                      item == null
                          ? '物品不存在或已删除'
                          : item.isArchived
                              ? '已用完，躺在归档里'
                              : '该物品暂无在库批次',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  if (item != null && !item.isArchived) ...[
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => showQuickIntakeSheet(context,
                          item: item, primary: null),
                      child: const Text('＋ 再次入库'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(
      LibraryItemView v, AppColors c, ColorScheme scheme, DateTime now) {
    final spots =
        v.activeBatches.map((b) => b.locationId).whereType<String>().toSet();
    final effLabel = ExpiryHelper.statusLabel(v.status, v.effectiveExpiry, now);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(v.item.icon ?? '📦', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${v.item.spec ?? '无规格'} · ${v.category?.icon ?? ''}${v.category?.name ?? '未分类'}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: c.inkFaint),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('在库 ${Fmt.quantity(v.totalRemaining)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(' ${v.primaryBatch?.unit ?? '件'}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.inkFaint)),
                      ],
                    ),
                  ],
                ),
              ),
              Tag.fromStatus(v.status, effLabel, scheme, c),
            ],
          ),
          const SizedBox(height: 8),
          Text('分属 ${spots.length} 个存放位置',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.inkFaint)),
        ],
      ),
    );
  }

  Widget _expiredGuide(BuildContext context, LibraryItemView v) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('该物品已过期，还要吗？不要就标记用完并入归档',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(
            onPressed: () => showFinishConfirm(context, v),
            child: const Text('标记用完'),
          ),
        ],
      ),
    );
  }
}

/// 批次卡（§5.13 核心单元）。
class BatchCard extends ConsumerWidget {
  final Batch batch;
  final LibraryItemView view;
  final String? locationName;

  const BatchCard({
    super.key,
    required this.batch,
    required this.view,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final now = DateTime.now();
    final eff = ExpiryHelper.effectiveExpiry(
        expiryDate: batch.expiryDate,
        openedAt: batch.openedAt,
        openShelfLifeDays: batch.openShelfLifeDays);
    final status = ExpiryHelper.statusOf(
        effectiveExpiryDate: eff, now: now, warningDays: 3);
    final percent = ExpiryHelper.remainingPercent(
        batch.remainingQuantity, batch.initialQuantity);
    final opened = batch.openedAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${batch.batchLabel}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: c.inkFaint)),
              const Spacer(),
              Tag.fromStatus(status, ExpiryHelper.statusLabel(status, eff, now),
                  scheme, c),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Fmt.quantity(batch.remainingQuantity),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Text(' / ${Fmt.quantity(batch.initialQuantity)} ${batch.unit}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.inkFaint)),
              const Spacer(),
              Text('$percent%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer)),
            ],
          ),
          const SizedBox(height: 6),
          Meter(value: percent / 100),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  '⏰ ${batch.expiryDate == null ? '无保质期' : '保质期至 ${Fmt.shortDate(batch.expiryDate!)}'}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.inkFaint)),
              InkWell(
                onTap: () => showOpenInfoSheet(context, batch),
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  opened
                      ? ExpiryHelper.openedLabel(
                          openedAt: batch.openedAt,
                          openShelfLifeDays: batch.openShelfLifeDays)
                      : '未开封',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: opened ? scheme.onPrimaryContainer : c.inkFaint),
                ),
              ),
              Text('📍 ${locationName ?? '未设位置'}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.inkFaint)),
            ],
          ),
          const SizedBox(height: 10),
          // 危险操作「✓完」左置离手；−1 高频给主样式；横向滚动兜底极窄屏防溢出
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _act(context, '✓完',
                    danger: true,
                    onTap: () =>
                        showFinishConfirm(context, view, batchId: batch.id)),
                if (!opened)
                  _act(context, '开封',
                      accent: true, onTap: () => showOpenSheet(context, batch)),
                _act(context, '−1',
                    accent: true, onTap: () => _consume(context, ref)),
                _act(context, '校正',
                    onTap: () => showAdjustSheet(context, ref, batch)),
                _act(context, '移位',
                    onTap: () => showMoveSheet(context, ref, batch)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _act(BuildContext context, String label,
      {required VoidCallback onTap, bool accent = false, bool danger = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          // 触摸目标高 48（design-system touch_target.minimum_android）
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: danger
                ? scheme.error.withValues(alpha: 0.1)
                : accent
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: danger
                      ? scheme.error
                      : accent
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant)),
        ),
      ),
    );
  }

  Future<void> _consume(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(inventoryActionsProvider);
    // 清零会触发自动归档并重建本卡片，await 前缓存 messenger 保证反馈可见
    final messenger = ScaffoldMessenger.of(context);
    final result = await actions.consume(
      itemId: batch.itemId,
      quantity: 1,
      source: LogSources.quickConsume,
      note: '批次 #${batch.batchLabel}',
    );
    final receipt = result.dataOrNull;
    if (receipt != null) {
      final logId = receipt.logId;
      if (logId != null) {
        showUndoBarOn(messenger, '已消耗 ${Fmt.quantity(receipt.qty)} ${batch.unit}',
            onUndo: () async {
          final undo = await actions.undoConsume(logId);
          if (undo.isFailure) {
            showToastOn(messenger, undo.errorMessage ?? '撤销失败');
          }
        });
      } else {
        showToastOn(messenger, '已记录 −${Fmt.quantity(receipt.qty)} ${batch.unit}');
      }
    } else {
      showToastOn(messenger, '该批次已无余量');
    }
  }
}
