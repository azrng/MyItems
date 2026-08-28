import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/view_models.dart';
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
                ...consuming.map((v) => ConsumingRow(view: v)),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                        label: '本月消耗', value: '${monthly.monthCount}', suffix: '件'),
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
                  .map((group) => DayGroupSection(day: group.$1, logs: group.$2)),
              if (logs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _visibleDays += 7),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => showConsumeSheet(context, v),
            borderRadius: BorderRadius.circular(12),
            child: Row(
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
                        v.lowRemaining ? '剩 $v.percent% · 余量低' : '剩余 $v.percent%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                v.lowRemaining ? scheme.onPrimaryContainer : c.inkFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
              _PillBtn(
                label: '−1',
                onTap: () => _quickMinus(context, ref, unit),
              ),
              const SizedBox(width: 8),
              _PillBtn(
                label: '记录消耗',
                onTap: () => showConsumeSheet(context, v),
              ),
              const SizedBox(width: 8),
              _PillBtn(
                label: '✓ 用完',
                primary: true,
                onTap: () => showFinishSheet(context, ref, v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickMinus(BuildContext context, WidgetRef ref, String unit) async {
    final actions = ref.read(inventoryActionsProvider);
    final result = await actions.consume(
        itemId: view.item.id,
        quantity: 1,
        source: LogSources.quickConsume);
    if (result is Success<String?> && context.mounted) {
      final logId = result.data;
      showToast(context, '−1 $unit');
      if (logId != null) {
        showUndoBar(context, '已消耗 1 $unit',
            onUndo: () => actions.undoConsume(logId));
      }
    } else if (result is Failure<String?> && context.mounted) {
      showToast(context, result.message);
    }
  }
}

class _PillBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _PillBtn({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: primary ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
