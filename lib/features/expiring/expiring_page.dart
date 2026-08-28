import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/expiry_helper.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/view_models.dart';
import '../../widgets/common.dart';
import '../../widgets/meter.dart';

/// 临期预警专页（requirement.md §5.9）。
class ExpiringPage extends ConsumerStatefulWidget {
  const ExpiringPage({super.key});

  @override
  ConsumerState<ExpiringPage> createState() => _ExpiringPageState();
}

class _ExpiringPageState extends ConsumerState<ExpiringPage> {
  String _chip = '全部';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final warningDays = ref.watch(settingsProvider.select((s) => s.expiryWarningDays));
    final all = ref.watch(expiringEntriesProvider);
    final now = DateTime.now();
    final entries =
        all.where((e) => e.matches(_chip, warningDays)).toList();

    return SubPage(
      title: '临期预警',
      body: Column(
        children: [
          // 预警 banner
          Container(
            margin: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding, 8, AppTheme.pagePadding, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: all.isEmpty
                  ? scheme.surfaceContainerLowest
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Text(all.isEmpty ? '🌿' : '⚠️',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        all.isEmpty
                            ? '没有需要优先处理的临期件'
                            : '${all.length} 件物品需要优先处理',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: all.isEmpty
                                ? scheme.onSurface
                                : scheme.onPrimaryContainer),
                      ),
                      Text(
                        '到期前 ≤$warningDays 天预警；开封类按建议限期计算',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: all.isEmpty
                                ? c.inkFaint
                                : scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 分组 chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
              children: [
                for (final chip in ExpireGroups.all)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _chipBtn(context, chip, scheme),
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const EmptyState(emoji: '🌤', title: '该分组暂无物品')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding, 8, AppTheme.pagePadding, 130),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _ExpiringRow(
                        entry: entries[i], now: now),
                  ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _chipBtn(BuildContext context, String chip, ColorScheme scheme) {
    final selected = _chip == chip;
    return InkWell(
      onTap: () => setState(() => _chip = chip),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.onSurface : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: selected ? scheme.onSurface : scheme.outline),
        ),
        child: Text(chip,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected
                    ? scheme.surfaceContainerLowest
                    : scheme.onSurfaceVariant)),
      ),
    );
  }
}

class _ExpiringRow extends StatelessWidget {
  final ExpiringEntry entry;
  final DateTime now;

  const _ExpiringRow({required this.entry, required this.now});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final e = entry;
    final primary = e.view.primaryBatch;
    final urgency = e.days < 0
        ? 1.0
        : e.days <= 7
            ? 1 - e.days / 7
            : 0.0;
    final dueLabel = e.days < 0
        ? '过期 ${-e.days} 天'
        : e.days == 0
            ? 'DUE IN 0 天'
            : 'DUE IN ${e.days} 天';

    return Container(
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
              Text(e.view.item.icon ?? '📦', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.view.item.name,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    Text(
                      '${primary?.locationId == null ? '未设位置' : ''}'
                      ' ${ExpiryHelper.contextLabel(
                        opened: primary?.openedAt != null,
                        openedAt: primary?.openedAt,
                        openShelfLifeDays: primary?.openShelfLifeDays,
                        expiryDate: primary?.expiryDate,
                      )}',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkFaint),
                    ),
                  ],
                ),
              ),
              Text(dueLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: e.days <= 1 ? scheme.error : scheme.onPrimaryContainer)),
            ],
          ),
          const SizedBox(height: 8),
          Meter(value: urgency, height: 5),
        ],
      ),
    );
  }
}

class ExpireGroups {
  static const all = ['全部', '24 小时内', '3 天内', '7 天内', '已开封超限'];
}
