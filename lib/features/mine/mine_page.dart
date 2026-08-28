import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/actions.dart';
import '../../providers/inventory_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/app_feedback.dart';
import 'mine_widgets.dart';

/// 我的（requirement.md §5.5）。
class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(dashboardProvider);
    final archived = ref.watch(archiveStatsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final locations = ref.watch(locationsProvider).value ?? const [];
    final expiring = ref.watch(expiringEntriesProvider);
    final backupFailed = !settings.lastBackupOk;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding, 12, AppTheme.pagePadding, 120),
          children: [
            HeroCard(
              nickname: settings.nickname,
              inStock: stats.inStock,
              totalConsume: archived.total,
              streak: stats.streak,
            ),
            const SizedBox(height: 16),
            BadgeRow(streak: stats.streak, archivedTotal: archived.total),
            const SizedBox(height: 22),
            _groupLabel('库存管理', c),
            _menuCard(context, [
              _MenuItem(
                emoji: '🗂',
                title: '物品分类管理',
                value: '${categories.length} 个分类',
                onTap: () => context.push('/categories'),
              ),
              _MenuItem(
                emoji: '📍',
                title: '存放位置管理',
                value: '${locations.length} 个位置',
                onTap: () => context.push('/locations'),
              ),
              _MenuItem(
                emoji: '🗄',
                title: '耗尽归档',
                value: '${archived.total} 条记录',
                onTap: () => context.push('/archive'),
              ),
              _MenuItem(
                emoji: '⏰',
                title: '临期预警清单',
                value: '${expiring.length} 件待处理',
                highlight: expiring.isNotEmpty,
                onTap: () => context.push('/expiring'),
              ),
            ], scheme),
            const SizedBox(height: 18),
            _groupLabel('数据与设备', c),
            _menuCard(context, [
              _MenuItem(
                emoji: '🔔',
                title: '提醒设置',
                subtitle: settings.dailySummaryEnabled
                    ? '每日 ${Fmt.clock(settings.summaryHour, settings.summaryMinute)} 摘要'
                    : '摘要提醒已关闭',
                onTap: () => showReminderSheet(context),
              ),
              _MenuItem(
                emoji: '💾',
                title: '存储管理与备份',
                value: settings.autoBackupEnabled ? '自动备份 · 开' : '自动备份 · 关',
                pillError: backupFailed,
                onTap: () => context.push('/backup'),
              ),
              _MenuItem(
                emoji: '🌗',
                title: '深色模式',
                value: settings.themeMode == ThemeMode.system
                    ? '跟随系统'
                    : settings.themeMode == ThemeMode.dark
                        ? '深色'
                        : '浅色',
                onTap: () => _cycleTheme(ref, settings.themeMode),
              ),
            ], scheme),
            const SizedBox(height: 18),
            _groupLabel('更多', c),
            _menuCard(context, [
              _MenuItem(
                emoji: '💬',
                title: '关于我们',
                value: 'v2.0.0',
                onTap: () => context.push('/about'),
              ),
            ], scheme),
            const SizedBox(height: 28),
            Center(
              child: Text('🌱 暖仓 · 把日子过得清清楚楚',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: c.inkFaint)),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleTheme(WidgetRef ref, ThemeMode current) {
    final next = current == ThemeMode.system
        ? ThemeMode.light
        : current == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.system;
    ref.read(settingsProvider.notifier).setThemeMode(next);
  }

  Widget _groupLabel(String text, AppColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
                color: c.inkFaint)),
      );

  Widget _menuCard(BuildContext context, List<Widget> items, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final String? value;
  final bool highlight;
  final bool pillError;
  final VoidCallback onTap;

  const _MenuItem({
    required this.emoji,
    required this.title,
    this.subtitle,
    this.value,
    this.highlight = false,
    this.pillError = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: c.inkFaint)),
                ],
              ),
            ),
            if (pillError)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('备份失败',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w900, color: scheme.error)),
              )
            else if (value != null)
              Text(value!,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: highlight ? scheme.error : c.inkFaint)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// 昵称编辑弹层（§3.7：同步首页问候语）。
Future<void> showNicknameSheet(BuildContext context, WidgetRef ref, String current) async {
  final ctrl = TextEditingController(text: current);
  final ok = await showAppSheet<bool>(
    context,
    child: AppBottomSheet(
      title: '怎么称呼你',
      body: TextField(
        controller: ctrl,
        maxLength: 12,
        decoration: const InputDecoration(labelText: '昵称'),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(settingsProvider.notifier).setNickname(ctrl.text);
  }
}

/// 提醒设置弹层（§4.9 / 十四次修订：阈值中心）。
Future<void> showReminderSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final s = container.read(settingsProvider);
  bool enabled = s.dailySummaryEnabled;
  int warningDays = s.expiryWarningDays;
  int lowPercent = s.lowRemainingPercent;

  await showAppSheet(
    context,
    child: StatefulBuilder(
      builder: (context, setState) {
        final scheme = Theme.of(context).colorScheme;
        return AppBottomSheet(
          title: '提醒设置',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchRow(
                title: '每日摘要提醒',
                subtitle: '每天一条聚合通知，汇总临期与已过期',
                value: enabled,
                onChanged: (v) => setState(() => enabled = v),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: enabled
                    ? () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime:
                              TimeOfDay(hour: s.summaryHour, minute: s.summaryMinute),
                        );
                        if (t != null) {
                          setState(() {
                            container.read(settingsProvider.notifier).setSummary(
                                hour: t.hour, minute: t.minute);
                          });
                        }
                      }
                    : null,
                child: AbsorbPointer(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const Text('提醒时间',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          Fmt.clock(s.summaryHour, s.summaryMinute),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('临期预警天数',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in ThresholdChoices.expiryWarningDays) ...[
                    Expanded(
                      child: _choice(
                        context,
                        '$d 天',
                        selected: warningDays == d,
                        onTap: () => setState(() => warningDays = d),
                      ),
                    ),
                    if (d != ThresholdChoices.expiryWarningDays.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              const Text('低余量阈值',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final p in ThresholdChoices.lowRemainingPercent) ...[
                    Expanded(
                      child: _choice(
                        context,
                        '$p%',
                        selected: lowPercent == p,
                        onTap: () => setState(() => lowPercent = p),
                      ),
                    ),
                    if (p != ThresholdChoices.lowRemainingPercent.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                final notifier = container.read(settingsProvider.notifier);
                if (enabled &&
                    !container.read(settingsProvider).dailySummaryEnabled) {
                  // 用户主动开启：此时申请通知权限（§4.9）
                  await container
                      .read(notificationServiceProvider)
                      .requestPermission();
                }
                await notifier.setSummary(enabled: enabled);
                await notifier.setWarningDays(warningDays);
                await notifier.setLowRemaining(lowPercent);
                await container.read(inventoryActionsProvider).runAutoBackupNow();
                if (context.mounted) {
                  showToast(context, '提醒设置已保存，立即生效');
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    ),
  );
}

Widget _choice(BuildContext context, String text,
    {required bool selected, required VoidCallback onTap}) {
  final scheme = Theme.of(context).colorScheme;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? scheme.onSurface : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? scheme.onSurface : scheme.outline),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: selected ? scheme.surfaceContainerLowest : scheme.onSurfaceVariant)),
    ),
  );
}
