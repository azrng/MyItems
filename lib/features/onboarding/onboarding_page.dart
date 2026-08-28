import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/actions.dart';
import '../../widgets/app_feedback.dart';

/// 首次启动引导（requirement.md §5.14）：单屏极简，写入预置分类/位置。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _busy = false;

  Future<void> _start({required bool withLocations}) async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(inventoryActionsProvider).seedOnboarding(withLocations: withLocations);
    if (mounted) {
      showToast(context, withLocations ? '已为你备好 8 个分类和 8 个位置 🧺' : '已创建 8 个预置分类 🧺');
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Center(child: Text('🧺', style: TextStyle(fontSize: 64))),
              const SizedBox(height: 16),
              const Center(
                child: Text('暖仓 WarmPantry',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('把日子过得清清楚楚',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer)),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _seedRow('🥕 食品食材 · 🧹 日用清洁 · 🍳 厨房小物 · 💊 药品保健'),
                    const SizedBox(height: 6),
                    _seedRow('💄 美妆护肤 · 🧃 酒水饮料 · 🔌 数码周边 · 📦 其他杂物'),
                    const SizedBox(height: 10),
                    Text(
                      '「开始使用」还会一并创建冰箱、橱柜、镜柜等 8 个常用存放位置；'
                      '它们都是普通记录，之后可以随意修改、停用。',
                      style: TextStyle(
                          fontSize: 12.5, height: 1.6, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: _busy ? null : () => _start(withLocations: true),
                child: const Text('开始使用'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : () => _start(withLocations: false),
                child: const Text('仅创建分类，跳过预置位置'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seedRow(String text) => Text(text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800));
}
