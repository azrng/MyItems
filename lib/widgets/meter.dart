import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 余量进度条：高 6 圆角 cream-2 槽 + accent→gold 渐变填充（component_patterns.meter）。
class Meter extends StatelessWidget {
  final double value; // 0-1
  final double height;

  const Meter({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return LayoutBuilder(builder: (context, box) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: box.maxWidth * v,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    scheme.primary,
                    Theme.of(context).extension<AppColors>()!.gold,
                  ]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
