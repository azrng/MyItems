import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'formatters.dart';

/// 效期状态分级（requirement.md §4.1）。
enum ExpiryStatus { expired, urgent, warning, attention, safe, none }

/// 批次余量/效期业务规则，全部为纯函数，便于测试。
class ExpiryHelper {
  ExpiryHelper._();

  /// 有效到期日 = min(ExpiryDate, OpenedAt + OpenShelfLifeDays)，仅有其一取该值。
  static DateTime? effectiveExpiry({
    DateTime? expiryDate,
    DateTime? openedAt,
    int? openShelfLifeDays,
  }) {
    final byOpen = (openedAt != null && openShelfLifeDays != null)
        ? openedAt.add(Duration(days: openShelfLifeDays))
        : null;
    if (expiryDate == null) return byOpen;
    if (byOpen == null) return expiryDate;
    return byOpen.isBefore(expiryDate) ? byOpen : expiryDate;
  }

  /// 距有效到期日的天数（今天到期 = 0；负数表示已过期天数）。
  static int daysUntil(DateTime? expiry, DateTime now) {
    if (expiry == null) return 999;
    final e = DateTime(expiry.year, expiry.month, expiry.day);
    final t = DateTime(now.year, now.month, now.day);
    return e.difference(t).inDays;
  }

  static ExpiryStatus statusOf({
    required DateTime? effectiveExpiryDate,
    required DateTime now,
    required int warningDays,
  }) {
    if (effectiveExpiryDate == null) return ExpiryStatus.none;
    final d = daysUntil(effectiveExpiryDate, now);
    if (d < 0) return ExpiryStatus.expired;
    if (d == 0 || d == 1) return ExpiryStatus.urgent; // 24 小时内（含今天）
    if (d <= warningDays) return ExpiryStatus.warning;
    if (d <= 7) return ExpiryStatus.attention;
    return ExpiryStatus.safe;
  }

  /// 是否「已开封超限」（开封限期早于今天，requirement.md §4.2）。
  static bool isOpenOverdue({
    DateTime? openedAt,
    int? openShelfLifeDays,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    if (openedAt == null || openShelfLifeDays == null) return false;
    return daysUntil(openedAt.add(Duration(days: openShelfLifeDays)), now) < 0;
  }

  /// 状态角标文案：已过期 3 天 / 今天到期 / 明天到期 / 还剩 5 天 / 安全 / 无期限。
  static String statusLabel(ExpiryStatus s, DateTime? effectiveExpiry, DateTime now) {
    switch (s) {
      case ExpiryStatus.expired:
        final d = -daysUntil(effectiveExpiry, now);
        return d <= 0 ? '已过期' : '已过期 $d 天';
      case ExpiryStatus.urgent:
        final d = daysUntil(effectiveExpiry, now);
        return d <= 0 ? '今天到期' : '明天到期';
      case ExpiryStatus.warning:
        return '还剩 ${daysUntil(effectiveExpiry, now)} 天';
      case ExpiryStatus.attention:
        return '还剩 ${daysUntil(effectiveExpiry, now)} 天';
      case ExpiryStatus.safe:
        return '安全';
      case ExpiryStatus.none:
        return '无期限';
    }
  }

  /// 状态主色（design-system semantic.expiry_days / status_tags）。
  static Color statusColor(ExpiryStatus s, ColorScheme scheme, AppColors c) {
    switch (s) {
      case ExpiryStatus.expired:
      case ExpiryStatus.urgent:
        return scheme.error;
      case ExpiryStatus.warning:
        return c.goldTextOnSoft;
      case ExpiryStatus.attention:
        return c.gold;
      case ExpiryStatus.safe:
        return c.olive;
      case ExpiryStatus.none:
        return c.inkFaint;
    }
  }

  /// 开封态文案：未开封 / 开封第 2 天 / 开封 150 天 / 开封满 6 个月（PAO）。
  static String openedLabel({DateTime? openedAt, int? openShelfLifeDays, DateTime? now}) {
    if (openedAt == null) return '未开封';
    now ??= DateTime.now();
    // 已开封天数 = 今天 − 开封日（daysUntil 面向未来，取反得到已过天数）
    final days = -daysUntil(openedAt, now);
    if (openShelfLifeDays != null && openShelfLifeDays >= 60) {
      final months = (openShelfLifeDays / 30).round();
      return '开封满 $months 个月（PAO）';
    }
    if (days <= 0) return '开封第 1 天';
    return '开封第 ${days + 1} 天';
  }

  /// 余量百分比（0-100，initial<=0 防御为 0）。
  static int remainingPercent(double remaining, double initial) {
    if (initial <= 0) return 0;
    return ((remaining / initial).clamp(0.0, 1.0) * 100).round();
  }

  /// 低余量判定（requirement.md §4.3，阈值默认 25%）。
  static bool isLowRemaining(double remaining, double initial, int thresholdPercent) {
    if (initial <= 0) return false;
    return remainingPercent(remaining, initial) <= thresholdPercent;
  }

  /// 临期页条目说明（requirement.md §5.9 上下文）。
  static String contextLabel({
    required bool opened,
    DateTime? openedAt,
    int? openShelfLifeDays,
    DateTime? expiryDate,
  }) {
    if (opened && openedAt != null) {
      final openedDays = -daysUntil(openedAt, DateTime.now());
      return '开封第 ${openedDays <= 0 ? 1 : openedDays + 1} 天';
    }
    if (expiryDate != null) return '整箱至 ${Fmt.shortDate(expiryDate)}';
    return '无保质期';
  }
}
