import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../data/database/app_database.dart';
import '../data/services/inventory_service.dart';
import 'core_providers.dart';
import 'settings_provider.dart';
import 'view_models.dart';

/// 原始数据流（drift watch → 响应式刷新）。
final categoriesProvider = StreamProvider<List<Category>>(
    (ref) => ref.watch(inventoryRepositoryProvider).watchCategories());

final locationsProvider = StreamProvider<List<StorageLocation>>(
    (ref) => ref.watch(inventoryRepositoryProvider).watchLocations());

final itemsProvider = StreamProvider<List<Item>>(
    (ref) => ref.watch(inventoryRepositoryProvider).watchItems());

final batchesProvider = StreamProvider<List<Batch>>(
    (ref) => ref.watch(inventoryRepositoryProvider).watchBatches());

final logsProvider = StreamProvider<List<InventoryLog>>(
    (ref) => ref.watch(inventoryRepositoryProvider).watchLogs());

final repurchasesProvider = StreamProvider<List<RepurchaseItem>>(
    (ref) => ref.watch(inventoryRepositoryProvider).watchRepurchases());

/// 待删集合（软删缓冲中的物品 id）。
final pendingDeletesProvider =
    FutureProvider<Set<String>>((ref) async {
  return (await ref
          .read(inventoryRepositoryProvider)
          .pendingDeleteIds())
      .toSet();
});

/// 物品聚合视图（过滤软删中的物品）。
final libraryViewsProvider = Provider<List<LibraryItemView>>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final batches = ref.watch(batchesProvider).value ?? const <Batch>[];
  final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
  final pending = ref.watch(pendingDeletesProvider).value ?? const <String>{};
  final settings = ref.watch(settingsProvider);
  final now = DateTime.now();
  final catById = {for (final c in categories) c.id: c};
  final views = <LibraryItemView>[];
  for (final i in items) {
    if (pending.contains(i.id)) continue;
    final v = ViewComposer.composeItem(
      item: i,
      category: catById[i.categoryId],
      allBatches: batches,
      now: now,
      warningDays: settings.expiryWarningDays,
      lowRemainingPercent: settings.lowRemainingPercent,
    );
    if (v != null) views.add(v);
  }
  return views;
});

/// 未归档物品视图（物品库/统计基线）。
final activeViewsProvider = Provider<List<LibraryItemView>>(
    (ref) => ref.watch(libraryViewsProvider).where((v) => !v.item.isArchived).toList());

/// 归档物品视图。
final archivedViewsProvider = Provider<List<LibraryItemView>>(
    (ref) => ref.watch(libraryViewsProvider).where((v) => v.item.isArchived).toList());

/// 临期条目（含开封超限），按天数升序。
final expiringEntriesProvider = Provider<List<ExpiringEntry>>((ref) {
  final now = DateTime.now();
  final entries = <ExpiringEntry>[];
  for (final v in ref.watch(activeViewsProvider)) {
    final e = ViewComposer.toExpiringEntry(v, now);
    if (e != null) entries.add(e);
  }
  entries.sort((a, b) {
    if (a.openOverdue != b.openOverdue) return a.openOverdue ? -1 : 1;
    return a.days.compareTo(b.days);
  });
  return entries;
});

/// 流水视图（含物品信息）。
final logViewsProvider = Provider<List<LogView>>((ref) {
  final logs = ref.watch(logsProvider).value ?? const <InventoryLog>[];
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final byId = {for (final i in items) i.id: i};
  return logs.map((l) => LogView(l, byId[l.itemId])).toList();
});

/// 仪表盘统计（§5.2）。
final dashboardProvider = Provider<({
  int inStock,
  int expiring,
  int todayConsume,
  List<int> weekBars,
  List<LogView> recentIntakes,
  int streak,
})>((ref) {
  final views = ref.watch(activeViewsProvider);
  final expiring = ref.watch(expiringEntriesProvider);
  final logs = ref.watch(logViewsProvider);
  final now = DateTime.now();
  return (
    inStock: views.length,
    expiring: expiring.length,
    todayConsume: InventoryService.todayConsumeCount(
        logs.map((l) => l.log).toList(), now),
    weekBars: InventoryService.weeklyConsume(logs.map((l) => l.log).toList(), now),
    recentIntakes: logs
        .where((l) => l.log.type == LogTypes.intake)
        .take(5)
        .toList(),
    streak: InventoryService.streakDays(logs.map((l) => l.log).toList(), now),
  );
});

/// 物品位置统计（物品库头部「N 件·N 个存放点」）。
final storageSpotCountProvider = Provider<int>((ref) {
  final views = ref.watch(activeViewsProvider);
  return views
      .expand((v) => v.activeBatches.map((b) => b.locationId))
      .whereType<String>()
      .toSet()
      .length;
});

/// 消耗中心月度统计。
final monthlyStatsProvider = Provider<({int monthCount, String topItem, int thrift})>((ref) {
  final logs = ref.watch(logViewsProvider);
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  return ViewComposer.monthlyConsumeStats(
      logs, {for (final i in items) i.id: i}, DateTime.now());
});

/// 归档统计。
final archiveStatsProvider = Provider<({int total, int avgDays, int month})>((ref) {
  final views = ref.watch(archivedViewsProvider);
  return ViewComposer.archiveStats(views.map((v) => v.item).toList(), DateTime.now());
});

/// 回购清单（状态）。
final repurchaseByItemProvider = Provider<Map<String, RepurchaseItem>>((ref) {
  final list = ref.watch(repurchasesProvider).value ?? const <RepurchaseItem>[];
  return {for (final r in list) r.itemId: r};
});

/// 开封限期模板（按分类记忆最近一次使用的天数，§4.2 / §4.6 保质期模板口径）。
final openTemplateByCategoryProvider = Provider<Map<String, int>>((ref) {
  final batches = ref.watch(batchesProvider).value ?? const <Batch>[];
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final catOf = {for (final i in items) i.id: i.categoryId};
  final map = <String, int>{};
  for (final b in batches
      .where((b) => b.openShelfLifeDays != null)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
    final cat = catOf[b.itemId];
    if (cat != null) map[cat] = b.openShelfLifeDays!;
  }
  return map;
});

/// 同分类最近一次入库效期天数（保质期快捷模板，§4.6）。
final expiryTemplateByCategoryProvider = Provider<Map<String, int>>((ref) {
  final batches = ref.watch(batchesProvider).value ?? const <Batch>[];
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  final catOf = {for (final i in items) i.id: i.categoryId};
  final map = <String, int>{};
  for (final b in batches
      .where((b) => b.expiryDate != null)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
    final cat = catOf[b.itemId];
    if (cat != null) {
      map[cat] = b.expiryDate!.difference(b.createdAt).inDays.clamp(1, 3650);
    }
  }
  return map;
});
