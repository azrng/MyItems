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
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: c.inkFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 里程碑徽章（P2）：仅悬挂已达成的奖牌（§5.5）——累计归档 10/50/100 件、连续记录 30 天；
/// 一枚都没达成时显示引导占位，不做默认灰态全员展示。
class BadgeRow extends StatelessWidget {
  final int streak;
  final int archivedTotal;

  const BadgeRow(
      {super.key, required this.streak, required this.archivedTotal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    final all = [
      (emoji: '🏅', label: '归档 10 件', ok: archivedTotal >= 10),
      (emoji: '🥈', label: '归档 50 件', ok: archivedTotal >= 50),
      (emoji: '🏆', label: '归档 100 件', ok: archivedTotal >= 100),
      (emoji: '🔥', label: '连记 30 天', ok: streak >= 30),
    ];
    final earned = all.where((b) => b.ok).toList();
    if (earned.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text('🎖 完成里程碑后，徽章会挂在这里',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c.inkFaint)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final b in earned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(b.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(b.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: scheme.onPrimaryContainer)),
              ],
            ),
          ),
      ],
    );
  }
}
