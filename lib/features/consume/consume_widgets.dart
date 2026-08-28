import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/actions.dart';
import '../../providers/view_models.dart';
import '../../core/utils/result.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/meter.dart';

/// 消耗中心私有组件：今日卡 / 记录消耗弹层 / 用完归档确认 / 日分组时间线。

class TodayCard extends StatelessWidget {
  final int count;
  final int streak;

  const TodayCard({super.key, required this.count, required this.streak});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8E4CF), Color(0xFFFFFCF5)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天已记录 $count 笔消耗',
                    style:
                        const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  streak >= 3
                      ? '连续记录 $streak 天 🔥 手感正顺'
                      : streak > 0
                          ? '连续记录 $streak 天，别断啦'
                          : '记上第一笔，就是好开始',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: c.inkFaint),
                ),
              ],
            ),
          ),
          if (count > 0)
            // 「今日已记」小印章（今日盖戳动效，design-system count_bump）
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.25, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.onPrimaryContainer, width: 1.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('今日已记',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: scheme.onPrimaryContainer)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 「记录消耗」底部弹层（§5.4 完整交互）。
Future<void> showConsumeSheet(BuildContext context, LibraryItemView v) async {
  final unit = v.primaryBatch?.unit ?? '件';
  final qtyCtrl = TextEditingController(text: '1');
  final noteCtrl = TextEditingController();
  double qty = 1;

  await showAppSheet(
    context,
    child: StatefulBuilder(builder: (context, setState) {
      final cap = v.totalRemaining;
      final over = qty > cap;
      final effective = over ? cap : qty;
      final after = cap - effective;
      final afterPercent = v.totalInitial <= 0
          ? 0
          : ((after / v.totalInitial).clamp(0.0, 1.0) * 100).round();

      return AppBottomSheet(
        title: '记录消耗 · ${v.item.name}',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('剩余 ${Fmt.quantity(cap)} $unit',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('$afterPercent%',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onPrimaryContainer)),
              ],
            ),
            const SizedBox(height: 6),
            Meter(value: afterPercent / 100),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in ['1', '0.5'])
                  ChoiceChip(
                    label: Text('−$preset $unit'),
                    selected: qty.toString() == preset,
                    onSelected: (_) => setState(() {
                      qty = double.parse(preset);
                      qtyCtrl.text = preset;
                    }),
                  ),
                if (unit == 'ml')
                  ChoiceChip(
                    label: const Text('−15 ml'),
                    selected: qty == 15,
                    onSelected: (_) => setState(() {
                      qty = 15;
                      qtyCtrl.text = '15';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '自定义用量（$unit）',
                errorText: qty <= 0 ? '用量必须大于 0' : (over ? '超出剩余量，将按剩余封顶' : null),
              ),
              onChanged: (s) => setState(() => qty = double.tryParse(s) ?? 0),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(hintText: '备注（选填，如 −8 ml 估算）'),
            ),
            const SizedBox(height: 10),
            Text('将写入：类型 消耗 · 来源 手动录入 · 位置快照 ${v.primaryBatch?.locationId == null ? '无' : '所在位置'}',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).extension<AppColors>()!.inkFaint)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: qty <= 0
                ? null
                : () async {
                    final container = ProviderScope.containerOf(context);
                    final actions = container.read(inventoryActionsProvider);
                    final result = await actions.consume(
                      itemId: v.item.id,
                      quantity: effective,
                      source: LogSources.manual,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (result is Success<String?>) {
                        showToast(context, '已记录 −${Fmt.quantity(effective)} $unit');
                        final logId = result.data;
                        if (logId != null) {
                          showUndoBar(context, '已消耗 ${Fmt.quantity(effective)} $unit',
                              onUndo: () => actions.undoConsume(logId));
                        }
                      } else {
                        showToast(context, '记录失败，请重试');
                      }
                    }
                  },
            child: Text('确认消耗 −${Fmt.quantity(effective)} $unit'),
          ),
        ],
      );
    }),
  );
}

/// 「✓ 用完」二次确认（含告别语）。
Future<void> showFinishSheet(
    BuildContext context, WidgetRef ref, LibraryItemView v) async {
  final days = DateTime.now().difference(v.item.createdAt).inDays.clamp(0, 99999);
  final ok = await confirmDialog(
    context,
    title: '「${v.item.name}」用完了吗？',
    content: '这件物品将从库存移除并写入消耗记录。\n\n'
        '🌿 这件物品陪伴了你 ${days < 1 ? '不到 1' : days} 天，谢谢它。',
    confirmText: '用完归档',
    danger: true,
  );
  if (!ok) return;
  final result =
      await ref.read(inventoryActionsProvider).finishItem(v.item.id);
  if (context.mounted) {
    if (result is Success<int>) {
      showToast(context, '已归档 · 陪伴了 ${result.data} 天 👋');
    } else {
      showToast(context, '操作失败，请重试');
    }
  }
}

/// 日分组时间线段落。
class DayGroupSection extends StatelessWidget {
  final DateTime day;
  final List<LogView> logs;

  const DayGroupSection({super.key, required this.day, required this.logs});

  static const _typeIcons = {
    LogTypes.intake: '＋',
    LogTypes.consume: '−',
    LogTypes.archive: '✓',
    LogTypes.open: '⭘',
    LogTypes.adjust: '≒',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(Fmt.dayGroup(day, DateTime.now()),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < logs.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: scheme.outlineVariant),
                _row(context, logs[i], c, scheme),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _row(BuildContext context, LogView l, AppColors c, ColorScheme scheme) {
    final sign = l.log.type == LogTypes.intake
        ? '＋${Fmt.quantity(l.log.quantity)} ${l.log.unit}'
        : l.log.type == LogTypes.consume
            ? '−${Fmt.quantity(l.log.quantity)} ${l.log.unit}'
            : l.log.type == LogTypes.adjust
                ? '≒ ${Fmt.quantity(l.log.quantity)} ${l.log.unit}'
                : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(_typeIcons[l.log.type] ?? '·',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: l.log.type == LogTypes.consume
                        ? scheme.onPrimaryContainer
                        : c.inkFaint)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(l.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                    if (sign.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(sign,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${l.log.source}'
                  '${l.log.locationText == null ? '' : ' · ${l.log.locationText}'}'
                  '${l.log.note == null ? '' : ' · ${l.log.note}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkFaint),
                ),
              ],
            ),
          ),
          Text(Fmt.time(l.log.createdAt),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.inkFaint)),
        ],
      ),
    );
  }
}
