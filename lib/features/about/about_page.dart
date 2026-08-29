import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/common.dart';

/// 关于我们（requirement.md §5.12）：仅 logo/版本/slogan/简介/联系我们。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = Theme.of(context).extension<AppColors>()!;
    return SubPage(
      title: '关于我们',
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding, vertical: 10),
        children: [
          const SizedBox(height: 16),
          Center(child: Text('🧺', style: const TextStyle(fontSize: 52))),
          const SizedBox(height: 12),
          const Center(
            child: Text('暖仓 WarmPantry',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('v2.0.0 · Build 1',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: c.inkFaint)),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('🧺 把日子过得清清楚楚',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimaryContainer)),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '为家庭打造的轻量物品管家：盯好保质期，记清每一笔消耗。'
            '囤货再多也心里有数，少一点过期浪费，多一点心中有数。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.7, fontWeight: FontWeight.w600, color: c.inkFaint),
          ),
          const SizedBox(height: 26),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(const ClipboardData(text: 'itzhangyunpeng@163.com'));
                if (context.mounted) showToast(context, '邮箱已复制 📋');
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 17)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('联系我们',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                    Text('邮件反馈',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: c.inkFaint)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '· 数据仅保存在本机，无网络传输\n'
              '· 国产手机若通知不准，可在系统设置中允许暖仓自启动与后台运行',
              style: TextStyle(
                  fontSize: 11, height: 1.8, fontWeight: FontWeight.w600, color: c.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
