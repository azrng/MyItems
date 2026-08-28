import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/expiry_helper.dart';

/// r8 小圆角 tag（design-system component_patterns.tag）。
class Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const Tag(this.text, {super.key, required this.bg, required this.fg});

  /// 由效期状态映射 tag 色阶。
  factory Tag.fromStatus(ExpiryStatus s, String text, ColorScheme scheme, AppColors c) {
    final kind = switch (s) {
      ExpiryStatus.expired || ExpiryStatus.urgent => 'red',
      ExpiryStatus.warning => 'org',
      ExpiryStatus.attention => 'yel',
      ExpiryStatus.safe => 'grn',
      ExpiryStatus.none => 'gry',
    };
    switch (kind) {
      case 'red':
        return Tag(text, bg: scheme.error.withValues(alpha: 0.14), fg: scheme.error);
      case 'org':
        return Tag(text, bg: scheme.primaryContainer, fg: scheme.onPrimaryContainer);
      case 'yel':
        return Tag(text, bg: c.goldSoft, fg: c.goldTextOnSoft);
      case 'grn':
        return Tag(text, bg: c.oliveSoft, fg: c.olive);
      default:
        return Tag(text, bg: scheme.surfaceContainerHighest, fg: c.inkFaint);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}
