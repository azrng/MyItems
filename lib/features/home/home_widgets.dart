import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/expiry_helper.dart';
import '../../core/utils/formatters.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/view_models.dart';
import '../../widgets/meter.dart';
import '../../widgets/tag.dart';

/// 首页私有组件：临期横滑卡 / 周柱图 / 最近入库行。

class ExpiringCard extends ConsumerWidget {
  final ExpiringEntry entry;
  final DateTime now;

  const ExpiringCard({super.key, required this.entry, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final v = entry.view;
    final primary = v.primaryBatch;
    final label = entry.days < 0
        ? '已过期 ${-entry.days} 天'
        : entry.days == 0
            ? '今天到期'
            : '还剩 ${entry.days} 天';
    final locations = ref.watch(locationsProvider).value ?? const [];
    final locName = locations
        .where((l) => l.id == primary?.locationId)
        .firstOrNull
        ?.name;

    return InkWell(
      onTap: () => context.push('/item/${v.item.id}'),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
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
                Text(v.item.icon ?? '📦', style: const TextStyle(fontSize: 18)),
                const Spacer(),
                Tag.fromStatus(v.status, label, scheme, c),
              ],
            ),
            const Spacer(),
            Text(v.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              '${locName ?? '未设位置'} · ${ExpiryHelper.contextLabel(
                opened: primary?.openedAt != null,
                openedAt: primary?.openedAt,
                openShelfLifeDays: primary?.openShelfLifeDays,
                expiryDate: primary?.expiryDate,
              )}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.inkFaint),
            ),
            const SizedBox(height: 8),
            Meter(value: v.percent / 100),
          ],
        ),
      ),
    );
  }
}

/// 七日消耗柱状图（design-system chart_styles.bar_style）。
class WeekBars extends StatelessWidget {
  final List<int> values;
  final int total;

  const WeekBars({super.key, required this.values, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final maxV = values.fold(1, (a, b) => a > b ? a : b);
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 76 * (values[i] / maxV),
                        width: 22,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7)),
                          gradient: values[i] == 0
                              ? LinearGradient(colors: [
                                  scheme.surfaceContainerHighest,
                                  scheme.outlineVariant,
                                ])
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFFDE7931), Color(0xFFBE5E18)]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[i],
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: c.inkFaint)),
                    ],
                  ),
                ),
                if (i != 6) const SizedBox(width: 9),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$total',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer)),
              Text(' 件 / 本周',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: c.inkFaint)),
            ],
          ),
        ],
      ),
    );
  }
}

class RecentIntakeRow extends StatelessWidget {
  final LogView log;

  const RecentIntakeRow({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locText = log.log.locationText == null ? '' : ' · ${log.log.locationText}';
    return InkWell(
      onTap: () => context.push('/item/${log.log.itemId}'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Text(log.displayIcon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${log.displayName} · ${Fmt.relative(log.log.createdAt, DateTime.now())}$locText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Text('＋${Fmt.quantity(log.log.quantity)} ${log.log.unit}',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}
