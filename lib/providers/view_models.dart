import '../../core/constants/app_constants.dart';
import '../../core/utils/expiry_helper.dart';
import '../../data/database/app_database.dart';

/// 视图模型（纯数据组合，可独立测试；Provider 层负责喂料）。

/// 物品库 / 列表共用的物品聚合视图。
class LibraryItemView {
  final Item item;
  final Category? category;
  final List<Batch> activeBatches;
  final Batch? primaryBatch; // FIFO 首个批次（最早有效到期日）
  final double totalRemaining;
  final double totalInitial;
  final int percent;
  final ExpiryStatus status;
  final DateTime? effectiveExpiry;
  final bool lowRemaining;
  final bool hasOpened;

  const LibraryItemView({
    required this.item,
    required this.category,
    required this.activeBatches,
    required this.primaryBatch,
    required this.totalRemaining,
    required this.totalInitial,
    required this.percent,
    required this.status,
    required this.effectiveExpiry,
    required this.lowRemaining,
    required this.hasOpened,
  });
}

/// 临期专页条目。
class ExpiringEntry {
  final LibraryItemView view;
  final int days; // 负数 = 已过期天数
  final bool openOverdue;

  const ExpiringEntry({required this.view, required this.days, required this.openOverdue});

  /// 临期页分组 chips（requirement.md §4.1）。
  bool matches(String chip, int warningDays) {
    switch (chip) {
      case '24 小时内':
        return days >= 0 && days <= 1;
      case '3 天内':
        return days >= 0 && days <= 3;
      case '7 天内':
        return days >= 0 && days <= 7;
      case '已开封超限':
        return openOverdue;
      default:
        return days < 0 || openOverdue || days <= warningDays || days <= 7;
    }
  }
}

/// 流水展示条目。
class LogView {
  final InventoryLog log;
  final Item? item;

  const LogView(this.log, this.item);

  String get displayName => item?.name ?? '已删除物品';
  String get displayIcon => item?.icon ?? '📦';
}

/// 纯组合函数。
class ViewComposer {
  ViewComposer._();

  static LibraryItemView? composeItem({
    required Item item,
    Category? category,
    required List<Batch> allBatches,
    required DateTime now,
    required int warningDays,
    required int lowRemainingPercent,
  }) {
    final active = allBatches
        .where((b) => b.itemId == item.id && b.remainingQuantity > 0)
        .toList();
    if (active.isEmpty && !item.isArchived) return null;
    double key(Batch b) {
      final e = ExpiryHelper.effectiveExpiry(
          expiryDate: b.expiryDate,
          openedAt: b.openedAt,
          openShelfLifeDays: b.openShelfLifeDays);
      return e?.millisecondsSinceEpoch.toDouble() ?? double.maxFinite;
    }

    active.sort((a, b) => key(a).compareTo(key(b)));
    final primary = active.isEmpty ? null : active.first;
    final remaining = active.fold<double>(0, (s, b) => s + b.remainingQuantity);
    final initial = active.fold<double>(0, (s, b) => s + b.initialQuantity);
    final eff = primary == null
        ? null
        : ExpiryHelper.effectiveExpiry(
            expiryDate: primary.expiryDate,
            openedAt: primary.openedAt,
            openShelfLifeDays: primary.openShelfLifeDays);
    return LibraryItemView(
      item: item,
      category: category,
      activeBatches: active,
      primaryBatch: primary,
      totalRemaining: remaining,
      totalInitial: initial,
      percent: ExpiryHelper.remainingPercent(remaining, initial),
      status: ExpiryHelper.statusOf(
          effectiveExpiryDate: eff, now: now, warningDays: warningDays),
      effectiveExpiry: eff,
      lowRemaining: ExpiryHelper.isLowRemaining(remaining, initial, lowRemainingPercent),
      hasOpened: active.any((b) => b.openedAt != null),
    );
  }

  /// 未归档且有待处理效期的物品 → 临期条目（含开封超限）。
  static ExpiringEntry? toExpiringEntry(LibraryItemView v, DateTime now) {
    if (v.item.isArchived || v.effectiveExpiry == null) return null;
    final days = ExpiryHelper.daysUntil(v.effectiveExpiry, now);
    final openOverdue = v.primaryBatch != null &&
        ExpiryHelper.isOpenOverdue(
            openedAt: v.primaryBatch!.openedAt,
            openShelfLifeDays: v.primaryBatch!.openShelfLifeDays,
            now: now);
    final inWindow = days <= 7 || openOverdue;
    if (!inWindow) return null;
    return ExpiringEntry(view: v, days: days, openOverdue: openOverdue);
  }

  /// 消耗中心「正在消耗」行（IsConsumable=true、未归档、有余量）。
  static bool isConsuming(LibraryItemView v) =>
      v.item.isConsumable && !v.item.isArchived && v.totalRemaining > 0;

  /// 日分组时间线（§5.4 消耗记录）。
  static List<(DateTime day, List<LogView>)> groupByDay(
      List<LogView> logs, DateTime now) {
    final buckets = <DateTime, List<LogView>>{};
    for (final l in logs) {
      final d = DateTime(l.log.createdAt.year, l.log.createdAt.month, l.log.createdAt.day);
      buckets.putIfAbsent(d, () => []).add(l);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (k, buckets[k]!)];
  }

  /// 归档统计（§4.4）：累计用完 / 平均使用周期 / 本月归档。
  static ({int total, int avgDays, int month}) archiveStats(
      List<Item> archivedItems, DateTime now) {
    var totalDays = 0;
    var month = 0;
    for (final i in archivedItems) {
      if (i.archivedAt != null) {
        totalDays += i.archivedAt!.difference(i.createdAt).inDays;
        if (i.archivedAt!.month == now.month && i.archivedAt!.year == now.year) {
          month++;
        }
      }
    }
    return (
      total: archivedItems.length,
      avgDays: archivedItems.isEmpty ? 0 : totalDays ~/ archivedItems.length,
      month: month,
    );
  }

  /// 消耗记录月度统计（§5.4）：本月消耗件数 / 最常消耗 / 节流成就。
  static ({int monthCount, String topItem, int thrift}) monthlyConsumeStats(
      List<LogView> logs, Map<String, Item> itemsById, DateTime now) {
    final monthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(now.year, now.month - 1);
    final thisMonth = logs
        .where((l) =>
            l.log.type == LogTypes.consume && l.log.createdAt.isAfter(monthStart))
        .toList();
    final lastMonth = logs
        .where((l) =>
            l.log.type == LogTypes.consume &&
            l.log.createdAt.isAfter(lastMonthStart) &&
            l.log.createdAt.isBefore(monthStart))
        .length;
    final byItem = <String, int>{};
    for (final l in thisMonth) {
      byItem[l.log.itemId] = (byItem[l.log.itemId] ?? 0) + 1;
    }
    String? top;
    var topCount = 0;
    byItem.forEach((id, c) {
      if (c > topCount) {
        topCount = c;
        top = itemsById[id]?.name ?? '已删除物品';
      }
    });
    return (
      monthCount: thisMonth.length,
      topItem: top ?? '—',
      thrift: lastMonth - thisMonth.length > 0 ? lastMonth - thisMonth.length : 0,
    );
  }
}
