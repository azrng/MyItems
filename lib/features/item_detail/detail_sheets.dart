import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../data/database/app_database.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../data/models/view_models.dart';
import '../../widgets/app_feedback.dart';

/// 详情页批次操作弹层：开封 / 开封信息纠错 / 余量校正 / 移位 / 用完确认（§4.2 / §4.3 / §5.13）。

/// 开封弹层：默认今天 + 分类模板天数。
Future<void> showOpenSheet(BuildContext context, Batch batch) async {
  final container = ProviderScope.containerOf(context);
  final templateDays =
      container.read(openTemplateByCategoryProvider)[_categoryOf(container, batch.itemId)];
  final dateCtrl = TextEditingController(text: Fmt.date(DateTime.now()));
  final daysCtrl = TextEditingController(text: '${templateDays ?? 7}');
  DateTime openedAt = DateTime.now();

  await showAppSheet(
    context,
    child: AppBottomSheet(
      title: '开封登记 · ${batch.batchLabel}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: openedAt,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                openedAt = d;
                dateCtrl.text = Fmt.date(d);
              }
            },
            child: AbsorbPointer(
              child: TextFormField(controller: dateCtrl, decoration: const InputDecoration(labelText: '开封日期')),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: daysCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '开封后建议限期（天）',
              helperText: templateDays == null
                  ? '如面包 4 天；化妆品 PAO 按月折算天数'
                  : '已按该分类上次使用预填（$templateDays 天）',
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () async {
            final days = int.tryParse(daysCtrl.text);
            final result = await container
                .read(inventoryActionsProvider)
                .openBatch(batch.id, openedAt, days);
            if (context.mounted) {
              Navigator.pop(context);
              showToast(context,
                  result is Success ? '已开封，效期将按开封限期计算' : '开封失败');
            }
          },
          child: const Text('确认开封'),
        ),
      ],
    ),
  );
}

/// 点开封态文案：纠错小弹层（取消开封 / 改开封日 / 改限期天数）。
Future<void> showOpenInfoSheet(BuildContext context, Batch batch) async {
  if (batch.openedAt == null) return;
  final scheme = Theme.of(context).colorScheme;
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('开封信息',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      content: Text(
        '${Fmt.date(batch.openedAt!)} 开封'
        '${batch.openShelfLifeDays == null ? '' : ' · 建议 ${batch.openShelfLifeDays} 天内用完'}\n'
        '修改会写入校正流水，可追溯。',
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: const Text('取消开封'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'edit'),
          child: const Text('修改'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('好的'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  final container = ProviderScope.containerOf(context);
  if (action == 'cancel') {
    await container.read(inventoryActionsProvider).cancelOpen(batch.id);
  } else if (action == 'edit') {
    await showOpenSheet(context, batch);
  }
}

/// 余量校正弹层：任意值 + 原因（§4.3）。
Future<void> showAdjustSheet(
    BuildContext context, WidgetRef ref, Batch batch) async {
  final valueCtrl =
      TextEditingController(text: Fmt.quantity(batch.remainingQuantity));
  final reasonCtrl = TextEditingController();
  final form = GlobalKey<FormState>();

  await showAppSheet(
    context,
    child: AppBottomSheet(
      title: '余量校正 · ${batch.batchLabel}',
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前 ${Fmt.quantity(batch.remainingQuantity)} ${batch.unit}，可改为任意值（含清零）',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).extension<AppColors>()!.inkFaint)),
            const SizedBox(height: 12),
            TextFormField(
              controller: valueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '改为（${batch.unit}）'),
              validator: (v) => double.tryParse(v ?? '') == null ? '请输入数值' : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: '原因（选填，如 漏记两笔）'),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () async {
            if (!(form.currentState?.validate() ?? false)) return;
            final result = await ref.read(inventoryActionsProvider).adjustRemaining(
                  batch.id,
                  double.parse(valueCtrl.text),
                  reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                );
            if (context.mounted) {
              Navigator.pop(context);
              showToast(context, result is Success ? '已校正并留痕' : '校正失败');
            }
          },
          child: const Text('确认校正'),
        ),
      ],
    ),
  );
}

/// 移位弹层。
Future<void> showMoveSheet(
    BuildContext context, WidgetRef ref, Batch batch) async {
  final locations = ref.read(locationsProvider).value ?? const <StorageLocation>[];
  final picked = await showAppSheet<StorageLocation>(
    context,
    child: AppBottomSheet(
      title: '移到哪个位置',
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
  if (picked != null && picked.id != batch.locationId) {
    await ref.read(inventoryActionsProvider).moveBatch(batch.id, picked.id);
    if (context.mounted) showToast(context, '已移到「${picked.name}」');
  }
}

/// 批次级「✓完」：仅清零该批次；物品全部批次耗尽时自动归档。
/// 撤销走 undoConsume（undoConsume 会一并回滚带标记的自动归档）。
Future<void> showFinishBatchConfirm(
    BuildContext context, WidgetRef ref, Batch batch) async {
  final ok = await confirmDialog(
    context,
    title: '批次 #${batch.batchLabel} 用完了吗？',
    content:
        '只清零这个批次（${Fmt.quantity(batch.remainingQuantity)} ${batch.unit}），其他批次不受影响。',
    confirmText: '批次用完',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  final actions = ref.read(inventoryActionsProvider);
  // 清零可能触发自动归档并重建本页，await 前缓存 messenger 保证反馈可见
  final messenger = ScaffoldMessenger.of(context);
  final result = await actions.finishBatch(batch.id);
  final receipt = result.dataOrNull;
  if (receipt == null) {
    showToastOn(messenger, '操作失败，请重试');
    return;
  }
  final logId = receipt.logId;
  if (logId != null) {
    showUndoBarOn(messenger, '已清零批次 #${batch.batchLabel}', onUndo: () async {
      final undo = await actions.undoConsume(logId);
      if (undo.isFailure) {
        showToastOn(messenger, undo.errorMessage ?? '撤销失败');
      }
    });
  } else {
    showToastOn(messenger, '批次 #${batch.batchLabel} 已用完');
  }
}

/// 删除指定批次：物理删除 + 流水留痕；物品因此耗尽时自动归档。
Future<void> showDeleteBatchConfirm(
    BuildContext context, WidgetRef ref, Batch batch) async {
  final hasStock = batch.remainingQuantity > 0;
  final ok = await confirmDialog(
    context,
    title: '删除批次 #${batch.batchLabel}？',
    content: hasStock
        ? '该批次还有 ${Fmt.quantity(batch.remainingQuantity)} ${batch.unit}，删除后不可恢复（消耗记录保留）。'
        : '删除后不可恢复（消耗记录保留）。',
    confirmText: '删除批次',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(inventoryActionsProvider).deleteBatch(batch.id);
  showToastOn(messenger, result is Success ? '已删除批次' : '删除失败');
}

/// 「✓完 / 标记用完」出库二次确认（告别语：入库 → 归档时长）。
/// 仅用于整物级用完（过期处置引导）；批次卡上的 ✓完 走 showFinishBatchConfirm。
Future<void> showFinishConfirm(BuildContext context, LibraryItemView v) async {
  final days = DateTime.now().difference(v.item.createdAt).inDays.clamp(0, 99999);
  final ok = await confirmDialog(
    context,
    title: '「${v.item.name}」用完了吗？',
    content: '这件物品将从库存移除并写入消耗记录。\n\n🌿 这件物品陪伴了你 ${days < 1 ? '不到 1' : days} 天，谢谢它。',
    confirmText: '用完归档',
    danger: true,
  );
  if (!ok) return;
  if (!context.mounted) return;
  final actions = ProviderScope.containerOf(context).read(inventoryActionsProvider);
  final result = await actions.finishItem(v.item.id);
  if (!context.mounted) return;
  if (result is Success<int>) {
    showToast(context, '已归档 · 陪伴了 ${result.data} 天 👋');
    Navigator.pop(context);
  } else {
    showToast(context, '操作失败，请重试');
  }
}

String? _categoryOf(ProviderContainer container, String itemId) {
  final views = container.read(libraryViewsProvider);
  return views.where((v) => v.item.id == itemId).firstOrNull?.item.categoryId;
}
