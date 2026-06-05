import 'package:flutter/material.dart';

import '../app_store.dart';
import '../main.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/item_card.dart';

class ExpiryGroupSection extends StatelessWidget {
  const ExpiryGroupSection({super.key, required this.group});

  final ExpiryGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(group.headerText,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ),
          ...group.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ItemCard(display: item),
              )),
        ],
      ),
    );
  }
}

class ExpiringPage extends StatefulWidget {
  const ExpiringPage({super.key});

  @override
  State<ExpiringPage> createState() => _ExpiringPageState();
}

class _ExpiringPageState extends State<ExpiringPage> {
  ExpiryStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: store.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('临期备忘提醒',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      '关注物品保值生命周期，减少浪费从清晰提醒开始。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ExpiryMetrics(
                groups: store.expiryGroups,
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 12),
              _ExpiryFilterTabs(
                groups: store.expiryGroups,
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 12),
              SearchField(
                hint: '搜索临期或已过期物品',
                initialValue: store.expirySearch,
                onChanged: store.setExpirySearch,
              ),
              const SizedBox(height: 14),
              if (store.errorMessage != null)
                ErrorBanner(message: store.errorMessage!),
              if (_visibleGroups(store.expiryGroups)
                  .every((group) => group.items.isEmpty))
                const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: '暂无临期提醒',
                    subtitle: '已过期和 7 天内到期的物品会显示在这里。'),
              ..._visibleGroups(store.expiryGroups)
                  .map((group) => ExpiryGroupSection(group: group)),
            ],
          ),
        );
      },
    );
  }

  List<ExpiryGroup> _visibleGroups(List<ExpiryGroup> groups) {
    if (_filter == null) return groups;
    return groups.where((group) => group.status == _filter).toList();
  }
}

class _ExpiryMetrics extends StatelessWidget {
  const _ExpiryMetrics({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<ExpiryGroup> groups;
  final ExpiryStatus? selected;
  final ValueChanged<ExpiryStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final expired = _count(ExpiryStatus.expired);
    final expiring = _count(ExpiryStatus.expiring);
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            icon: Icons.error_outline,
            label: '已过期物品',
            value: '$expired 件',
            color: const Color(0xFFF43F5E),
            onTap: () => onSelected(
                selected == ExpiryStatus.expired ? null : ExpiryStatus.expired),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricTile(
            icon: Icons.notifications_active_outlined,
            label: '即将过期物品',
            value: '$expiring 件',
            color: const Color(0xFFF59E0B),
            onTap: () => onSelected(selected == ExpiryStatus.expiring
                ? null
                : ExpiryStatus.expiring),
          ),
        ),
      ],
    );
  }

  int _count(ExpiryStatus status) {
    return groups
        .where((group) => group.status == status)
        .fold(0, (sum, group) => sum + group.items.length);
  }
}

class _ExpiryFilterTabs extends StatelessWidget {
  const _ExpiryFilterTabs({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<ExpiryGroup> groups;
  final ExpiryStatus? selected;
  final ValueChanged<ExpiryStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final all = groups.fold(0, (sum, group) => sum + group.items.length);
    final expired = groups
        .where((group) => group.status == ExpiryStatus.expired)
        .fold(0, (sum, group) => sum + group.items.length);
    final expiring = groups
        .where((group) => group.status == ExpiryStatus.expiring)
        .fold(0, (sum, group) => sum + group.items.length);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withAlpha(100),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _SegmentButton(
              label: '看全部异常 ($all)',
              selected: selected == null,
              onTap: () => onSelected(null)),
          _SegmentButton(
              label: '只看已过期 ($expired)',
              selected: selected == ExpiryStatus.expired,
              onTap: () => onSelected(ExpiryStatus.expired)),
          _SegmentButton(
              label: '只看即将过期 ($expiring)',
              selected: selected == ExpiryStatus.expiring,
              onTap: () => onSelected(ExpiryStatus.expiring)),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: selected ? Theme.of(context).colorScheme.surface : null,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
