import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/view_models.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';
import '../../widgets/tag.dart';

/// 耗尽归档（requirement.md §5.10 / §4.4 回购）。
class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  String? _chip; // 本月 / 食品 / 日化 / 药品 / 值得回购 ⭐ / null=全部

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(archiveStatsProvider);
    final archived = ref.watch(archivedViewsProvider);
    final repurchase = ref.watch(repurchaseByItemProvider);
    final now = DateTime.now();
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    var entries = archived;
    if (_chip == '本月') {
      entries = entries
          .where((v) =>
              v.item.archivedAt != null &&
              v.item.archivedAt!.month == now.month &&
              v.item.archivedAt!.year == now.year)
          .toList();
    } else if (_chip == '值得回购 ⭐') {
      entries = entries.where((v) => repurchase.containsKey(v.item.id)).toList();
    } else if (_chip != null) {
      final cat = categories.where((cat) => cat.name.contains(_chip!)).firstOrNull;
      if (cat != null) {
        entries = entries.where((v) => v.item.categoryId == cat.id).toList();
      }
    }

    return SubPage(
      title: '耗尽归档',
      actions: [
        TextButton(
          onPressed: archived.isEmpty
              ? null
              : () async {
                  final ok = await confirmDialog(context,
                      title: '清空归档？',
                      content: '仅清除归档记录，不动消耗流水历史。',
                      confirmText: '清空',
                      danger: true);
                  if (!ok) return;
                  await ref.read(inventoryActionsProvider).clearArchive();
                  if (context.mounted) showToast(context, '归档已清空');
                },
          child: const Text('清空'),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(label: '累计用完', value: '${stats.total}', suffix: '件'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(label: '平均使用周期', value: '${stats.avgDays}', suffix: '天'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(label: '本月归档', value: '${stats.month}', suffix: '件'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
              children: [
                for (final chip in [null, ...ArchiveFilterChips.all])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _chip = chip),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: _chip == chip
                              ? scheme.onSurface
                              : scheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color:
                                  _chip == chip ? scheme.onSurface : scheme.outline),
                        ),
                        child: Text(chip ?? '全部',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _chip == chip
                                    ? scheme.surfaceContainerLowest
                                    : scheme.onSurfaceVariant)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? EmptyState(
                    emoji: '🗄',
                    title: '还没有用完的物品',
                    subtitle: '用完的物品会在这里安家，随时「再买一次」',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding, 8, AppTheme.pagePadding, 130),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _ArchiveRow(
                      view: entries[i],
                      repurchase: repurchase[entries[i].item.id],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveRow extends ConsumerWidget {
  final LibraryItemView view;
  final RepurchaseItem? repurchase;

  const _ArchiveRow({required this.view, required this.repurchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final item = view.item;
    final days = item.archivedAt == null
        ? 0
        : item.archivedAt!.difference(item.createdAt).inDays;
    final inCart = repurchase?.status == '已在购物车';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: 0.45,
            child: Text(item.icon ?? '📦', style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                    if (repurchase != null) ...[
                      const SizedBox(width: 6),
                      Tag(inCart ? '已在购物车' : '待购',
                          bg: inCart
                              ? c.oliveSoft
                              : scheme.primaryContainer,
                          fg: inCart ? c.olive : scheme.onPrimaryContainer),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.archivedAt == null ? '' : '${Fmt.date(item.archivedAt!)} 用完 · '}使用 $days 天',
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkFaint),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              final actions = ref.read(inventoryActionsProvider);
              if (repurchase == null) {
                actions.addToRepurchase(item.id);
                showToast(context, '已按上次规格生成采购单 🛒');
                context.push('/editor', extra: item.id);
              } else {
                actions.toggleRepurchase(repurchase!);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: repurchase == null
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                repurchase == null ? '再买一次' : (inCart ? '移出购物车' : '去购物车'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: repurchase == null
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
