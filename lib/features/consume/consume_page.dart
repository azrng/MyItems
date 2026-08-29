import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../data/models/view_models.dart';
import '../../widgets/common.dart';
import '../../widgets/meter.dart';
import 'consume_widgets.dart';
import '../../widgets/app_feedback.dart';

/// 消耗中心（requirement.md §5.4，两分段）。
class ConsumePage extends ConsumerStatefulWidget {
  const ConsumePage({super.key});

  @override
  ConsumerState<ConsumePage> createState() => _ConsumePageState();
}

class _ConsumePageState extends ConsumerState<ConsumePage> {
  int _segment = 0; // 0 正在消耗 / 1 消耗记录
  int _visibleDays = 7; // 消耗记录分页：先展示近 7 天，加载更早再回溯

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final views = ref.watch(activeViewsProvider);
    final consuming = views.where(ViewComposer.isConsuming).toList();
    final logs = ref.watch(logViewsProvider);
    final stats = ref.watch(dashboardProvider);
    final monthly = ref.watch(monthlyStatsProvider);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding, 12, AppTheme.pagePadding, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('消耗中心 🔥',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('把每一笔使用都记上账',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c.inkFaint)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Segmented(
              index: _segment,
              onChange: (i) => setState(() => _segment = i),
            ),
            const SizedBox(height: 16),
            if (_segment == 0) ...[
              TodayCard(count: stats.todayConsume, streak: stats.streak),
              const SizedBox(height: 16),
              if (consuming.isEmpty)
                EmptyState(
                  emoji: '🧘',
                  title: '没有正在消耗的物品',
                  subtitle: '录入物品并开始使用后，会出现在这里',
                )
              else
                ...consuming.map(
                    (v) => ConsumingRow(key: ValueKey(v.item.id), view: v)),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                        label: '本月消耗',
                        value: '${monthly.monthCount}',
                        suffix: '件'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                        label: '最常消耗', value: monthly.topItem, isText: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                        label: '节流成就',
                        value: monthly.thrift > 0 ? '${monthly.thrift}' : '0',
                        suffix: monthly.thrift > 0 ? '件 ↓' : '件'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...ViewComposer.groupByDay(
                      logs.take(_visibleDays * 10).toList(), now)
                  .take(_visibleDays)
                  .map((group) => DayGroupSection(
                      key: ValueKey(group.$1), day: group.$1, logs: group.$2)),
              if (logs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _visibleDays += 7),
                    child: const Text('加载更早的记录'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChange;

  const _Segmented({required this.index, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChange(i),
                borderRadius: BorderRadius.circular(13),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index
                        ? scheme.surfaceContainerLowest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      i == 0 ? '正在消耗' : '消耗记录',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: i == index
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 进行中物品行（§5.4）：percent + meter + −1 + ✓。
class ConsumingRow extends ConsumerWidget {
  final LibraryItemView view;
  const ConsumingRow({super.key, required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final v = view;
    final unit = v.primaryBatch?.unit ?? '件';

    // 整卡可点开记录弹层；按钮用 GestureDetector(opaque) 保证命中
    //（真机回归曾出现 InkWell pill 在首行无法命中的问题，opaque 直接收取事件）
    return InkWell(
      onTap: () => showConsumeSheet(context, v),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(v.item.icon ?? '📦', style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        v.lowRemaining
                            ? '剩 ${v.percent}% · 余量低'
                            : '剩余 ${v.percent}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: v.lowRemaining
                                ? scheme.onPrimaryContainer
                                : c.inkFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Meter(value: v.percent / 100),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${Fmt.quantity(v.totalRemaining)} $unit',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: c.inkFaint)),
                const Spacer(),
                // 危险操作左置离手，最高频的 −1 主样式放最右拇指位
                _PillBtn(
                  label: '✓ 用完',
                  danger: true,
                  onTap: () => showFinishSheet(context, ref, v),
                ),
                const SizedBox(width: 8),
                _PillBtn(
                  label: '记录消耗',
                  onTap: () => showConsumeSheet(context, v),
                ),
                const SizedBox(width: 8),
                _PillBtn(
                  label: '−1',
                  primary: true,
                  onTap: () => _quickMinus(context, ref, unit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickMinus(
      BuildContext context, WidgetRef ref, String unit) async {
    final actions = ref.read(inventoryActionsProvider);
    // 清零会触发自动归档并移除本行，await 前缓存 messenger 保证反馈可见
    final messenger = ScaffoldMessenger.of(context);
    final result = await actions.consume(
        itemId: view.item.id, quantity: 1, source: LogSources.quickConsume);
    final receipt = result.dataOrNull;
    if (receipt != null) {
      final logId = receipt.logId;
      if (logId != null) {
        showUndoBarOn(messenger, '已消耗 ${Fmt.quantity(receipt.qty)} $unit',
            onUndo: () async {
          final undo = await actions.undoConsume(logId);
          if (undo.isFailure) {
            showToastOn(messenger, undo.errorMessage ?? '撤销失败');
          }
        });
      } else {
        showToastOn(messenger, '−${Fmt.quantity(receipt.qty)} $unit');
      }
    } else {
      showToastOn(messenger, result.errorMessage ?? '消耗失败');
    }
  }
}

class _PillBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final bool danger;
  final VoidCallback onTap;

  const _PillBtn({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 触摸目标高 48（design-system touch_target.minimum_android）
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: danger
              ? scheme.error.withValues(alpha: 0.1)
              : primary
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: danger
                  ? scheme.error
                  : primary
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
