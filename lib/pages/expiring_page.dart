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
            child: Text('${group.icon} ${group.headerText}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
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

class ExpiringPage extends StatelessWidget {
  const ExpiringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: store.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              SearchField(
                hint: '搜索临期或已过期物品',
                initialValue: store.expirySearch,
                onChanged: store.setExpirySearch,
              ),
              const SizedBox(height: 12),
              if (store.errorMessage != null)
                ErrorBanner(message: store.errorMessage!),
              if (store.expiryGroups.every((group) => group.items.isEmpty))
                const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: '暂无临期提醒',
                    subtitle: '已过期和 7 天内到期的物品会显示在这里。'),
              ...store.expiryGroups
                  .map((group) => ExpiryGroupSection(group: group)),
            ],
          ),
        );
      },
    );
  }
}
