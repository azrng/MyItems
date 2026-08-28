import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'mine_page.dart';

/// 我的页私有组件：hero 卡 + 里程碑徽章行（§5.5，徽章 P2）。

class HeroCard extends ConsumerWidget {
  final String nickname;
  final int inStock;
  final int totalConsume;
  final int streak;

  const HeroCard({
    super.key,
    required this.nickname,
    required this.inStock,
    required this.totalConsume,
    required this.streak,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: () => showNicknameSheet(context, ref, nickname),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('🧺', style: TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(nickname,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_rounded, size: 13, color: c.inkFaint),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('点一下改称呼，首页问候语会同步',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 里程碑徽章（P2 初版）：累计归档 10/50/100 件、连续记录 30 天。
class BadgeRow extends StatelessWidget {
  final int streak;
  final int archivedTotal;

  const BadgeRow({super.key, required this.streak, required this.archivedTotal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final badges = [
      (emoji: '🏅', label: '归档 10 件', ok: archivedTotal >= 10),
      (emoji: '🥈', label: '归档 50 件', ok: archivedTotal >= 50),
      (emoji: '🏆', label: '归档 100 件', ok: archivedTotal >= 100),
      (emoji: '🔥', label: '连记 30 天', ok: streak >= 30),
    ];
    return Row(
      children: [
        for (final b in badges) ...[
          Expanded(
            child: Opacity(
              opacity: b.ok ? 1 : 0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: b.ok ? scheme.primaryContainer : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(b.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(b.label,
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: b.ok ? scheme.onPrimaryContainer : c.inkFaint)),
                  ],
                ),
              ),
            ),
          ),
          if (b != badges.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
