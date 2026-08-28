import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import 'home_widgets.dart';

/// 首页仪表盘（requirement.md §5.2，原型 home.html）。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final stats = ref.watch(dashboardProvider);
    final expiring = ref.watch(expiringEntriesProvider);
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding, 12, AppTheme.pagePadding, 120),
          children: [
            _GreetHeader(settings: settings, now: now),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: '在库',
                    value: '${stats.inStock}',
                    suffix: '件',
                    onTap: () => context.go('/library'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: '⚠️临期',
                    value: '${stats.expiring}',
                    suffix: '件',
                    alert: stats.expiring > 0,
                    onTap: () => context.push('/expiring'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: '今日消耗',
                    value: '${stats.todayConsume}',
                    suffix: '件',
                    onTap: () => context.go('/consume'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SectionHeader(
              emoji: '🍜',
              title: '先吃先喝 · 临期专区',
              action: '全部 ›',
              onAction: () => context.push('/expiring'),
            ),
            if (expiring.isEmpty)
              _emptyExpiling(scheme, c)
            else
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: expiring.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) =>
                      ExpiringCard(entry: expiring[i], now: now),
                ),
              ),
            const SizedBox(height: 24),
            SectionHeader(
              emoji: '✨',
              title: '快捷入口',
            ),
            const _QuickEntries(),
            const SizedBox(height: 24),
            SectionHeader(
              emoji: '📊',
              title: '本周消耗节奏',
              action: '查看记录 ›',
              onAction: () => context.go('/consume'),
            ),
            WeekBars(values: stats.weekBars, total: stats.weekBars.fold(0, (a, b) => a + b)),
            const SizedBox(height: 8),
            _StreakLine(stats.streak),
            const SizedBox(height: 24),
            SectionHeader(
              emoji: '📥',
              title: '最近入库',
              action: '物品库 ›',
              onAction: () => context.go('/library'),
            ),
            if (stats.recentIntakes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('还没有入库记录，点右下角 ＋ 添加第一件吧',
                    style: TextStyle(fontSize: 12.5, color: c.inkFaint)),
              )
            else
              ...stats.recentIntakes.map((l) => RecentIntakeRow(log: l)),
          ],
        ),
      ),
    );
  }

  Widget _emptyExpiling(ColorScheme scheme, AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('一切安好，没有需要优先处理的临期件',
                style: TextStyle(fontSize: 12.5, color: c.inkFaint, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _GreetHeader extends ConsumerWidget {
  final SettingsState settings;
  final DateTime now;

  const _GreetHeader({required this.settings, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final actions = ref.read(inventoryActionsProvider);
    final hasUnread = ref.watch(settingsProvider.select((s) {
      final controller = ref.read(settingsProvider.notifier);
      return controller.bellHasUnread;
    }));
    final expiringCount = ref.watch(expiringEntriesProvider).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Fmt.headerDate(now),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: c.inkFaint)),
              const SizedBox(height: 6),
              Text(
                '${Fmt.greeting(now)}，${settings.nickname} 👋',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        _BellButton(
          hasUnread: hasUnread && expiringCount > 0,
          onTap: () async {
            await actions.onBellTapped();
            if (context.mounted) context.push('/expiring');
          },
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => context.go('/mine'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text('🧺', style: TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onTap;

  const _BellButton({required this.hasUnread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Center(
                child: Icon(Icons.notifications_none_rounded,
                    size: 22, color: scheme.onSurface)),
            if (hasUnread)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: scheme.error, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickEntries extends StatelessWidget {
  const _QuickEntries();
  static const entries = [
    (emoji: '➕', label: '添加', route: '/editor'),
    (emoji: '🗂', label: '分类', route: '/categories'),
    (emoji: '📍', label: '位置', route: '/locations'),
    (emoji: '🗄', label: '归档', route: '/archive'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final e in entries) ...[
          Expanded(
            child: InkWell(
              onTap: () {
                if (e.route == '/editor') {
                  context.push(e.route);
                } else {
                  context.push(e.route);
                }
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(e.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(e.label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          if (e != entries.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StreakLine extends StatelessWidget {
  final int streak;
  const _StreakLine(this.streak);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final text = streak >= 3
        ? '↑ 习惯良好 · 连续记录 $streak 天'
        : streak > 0
            ? '连续记录 $streak 天，继续保持'
            : '记录一次消耗，开启你的连续打卡';
    return Text(text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.inkFaint));
  }
}
