import 'package:drift/drift.dart' hide Batch;

import '../database/app_database.dart';

/// 消耗落点：批次 + 本笔扣减量（FIFO 分配结果）。
class BatchDeduction {
  final Batch batch;
  final double amount;
  const BatchDeduction(this.batch, this.amount);
}

/// 数据访问边界（backend-AGENTS.md：抽象类 + 实现，异步优先）。
abstract class InventoryRepository {
  // 分类
  Stream<List<Category>> watchCategories();
  Future<List<Category>> getCategories();
  Future<void> insertCategory(CategoriesCompanion c);
  Future<void> updateCategory(CategoriesCompanion c);
  Future<int> countItemsOfCategory(String categoryId);
  Future<void> deleteCategory(String id);
  Future<void> reorderCategories(List<({String id, int sortOrder})> orders);

  // 位置
  Stream<List<StorageLocation>> watchLocations({bool activeOnly = false});
  Future<List<StorageLocation>> getLocations({bool activeOnly = false});
  Future<StorageLocation?> getLocation(String id);
  Future<void> insertLocation(StorageLocationsCompanion l);
  Future<void> updateLocation(StorageLocationsCompanion l);
  Future<void> deactivateLocation(String id);

  // 物品
  Stream<List<Item>> watchItems({bool includeArchived = true});
  Future<Item?> getItem(String id);
  Future<List<Item>> findByName(String name);
  Future<void> insertItem(ItemsCompanion i);
  Future<void> updateItem(ItemsCompanion i);
  Future<void> markArchived(String itemId, bool archived, {DateTime? at});
  Future<void> deleteItemsAndBatches(List<String> itemIds);
  Future<void> deleteItemsKeepLogs(List<String> itemIds);

  // 批次
  Stream<List<Batch>> watchBatches();
  Future<List<Batch>> getBatchesOfItems(List<String> itemIds);
  Future<Batch?> getBatch(String id);
  Future<void> insertBatch(BatchesCompanion b);
  Future<void> updateBatch(BatchesCompanion b);
  Future<void> deleteBatches(List<String> batchIds);
  Future<void> applyDeductions(List<BatchDeduction> deductions);
  Future<void> setImagePath(String batchId, String? path);

  // 流水
  Stream<List<InventoryLog>> watchLogs();
  Future<List<InventoryLog>> getLogs({int limit, int offset});
  Future<void> insertLogs(List<InventoryLogsCompanion> logs);
  Future<void> deleteLog(String logId);

  // 回购
  Stream<List<RepurchaseItem>> watchRepurchases();
  Future<void> upsertRepurchase(RepurchaseItemsCompanion r);
  Future<void> deleteRepurchase(String id);

  // 软删缓冲
  Future<List<String>> pendingDeleteIds();

  // 设置 KV
  Future<String?> getSetting(String key);
  Future<Map<String, String>> getAllSettings();
  Future<void> setSetting(String key, String value);
  Future<void> setSettings(Map<String, String> entries);

  /// 备份恢复用：整库替换（备份恢复链路）。
  Future<void> replaceAllData({
    required List<CategoriesCompanion> categories,
    required List<StorageLocationsCompanion> locations,
    required List<ItemsCompanion> items,
    required List<BatchesCompanion> batches,
    required List<InventoryLogsCompanion> logs,
    required List<RepurchaseItemsCompanion> repurchases,
  });
}

class DriftInventoryRepository implements InventoryRepository {
  final AppDatabase db;
  DriftInventoryRepository(this.db);

  // ---------- 分类 ----------
  @override
  Stream<List<Category>> watchCategories() =>
      (db.select(db.categories)..orderBy([(u) => OrderingTerm.asc(u.sortOrder)])).watch();

  @override
  Future<List<Category>> getCategories() =>
      (db.select(db.categories)..orderBy([(u) => OrderingTerm.asc(u.sortOrder)])).get();

  @override
  Future<void> insertCategory(CategoriesCompanion c) =>
      db.into(db.categories).insert(c, mode: InsertMode.insertOrReplace);

  @override
  Future<void> updateCategory(CategoriesCompanion c) =>
      db.update(db.categories).write(c);

  @override
  Future<int> countItemsOfCategory(String categoryId) async {
    final query = db.selectOnly(db.items)
      ..addColumns([countAll()])
      ..where(db.items.categoryId.equals(categoryId) & db.items.isArchived.equals(false));
    final row = await query.getSingle();
    return row.read(countAll()) ?? 0;
  }

  @override
  Future<void> deleteCategory(String id) =>
      (db.delete(db.categories)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> reorderCategories(List<({String id, int sortOrder})> orders) {
    return db.batch((b) {
      for (final o in orders) {
        b.update(db.categories, CategoriesCompanion(sortOrder: Value(o.sortOrder)),
            where: (t) => t.id.equals(o.id));
      }
    });
  }

  // ---------- 位置 ----------
  @override
  Stream<List<StorageLocation>> watchLocations({bool activeOnly = false}) {
    final q = db.select(db.storageLocations)
      ..orderBy([(u) => OrderingTerm.asc(u.sortOrder)]);
    if (activeOnly) q.where((t) => t.isActive.equals(true));
    return q.watch();
  }

  @override
  Future<List<StorageLocation>> getLocations({bool activeOnly = false}) {
    final q = db.select(db.storageLocations)
      ..orderBy([(u) => OrderingTerm.asc(u.sortOrder)]);
    if (activeOnly) q.where((t) => t.isActive.equals(true));
    return q.get();
  }

  @override
  Future<StorageLocation?> getLocation(String id) =>
      (db.select(db.storageLocations)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<void> insertLocation(StorageLocationsCompanion l) =>
      db.into(db.storageLocations).insert(l, mode: InsertMode.insertOrReplace);

  @override
  Future<void> updateLocation(StorageLocationsCompanion l) =>
      db.update(db.storageLocations).write(l);

  @override
  Future<void> deactivateLocation(String id) =>
      (db.update(db.storageLocations)..where((t) => t.id.equals(id)))
          .write(StorageLocationsCompanion(isActive: const Value(false)));

  // ---------- 物品 ----------
  @override
  Stream<List<Item>> watchItems({bool includeArchived = true}) {
    final q = db.select(db.items)
      ..orderBy([(u) => OrderingTerm.desc(u.createdAt)]);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    return q.watch();
  }

  @override
  Future<Item?> getItem(String id) =>
      (db.select(db.items)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<List<Item>> findByName(String name) =>
      (db.select(db.items)..where((t) => t.name.equals(name))).get();

  @override
  Future<void> insertItem(ItemsCompanion i) =>
      db.into(db.items).insert(i, mode: InsertMode.insertOrReplace);

  @override
  Future<void> updateItem(ItemsCompanion i) => db.update(db.items).write(i);

  @override
  Future<void> markArchived(String itemId, bool archived, {DateTime? at}) {
    return (db.update(db.items)..where((t) => t.id.equals(itemId))).write(ItemsCompanion(
          isArchived: Value(archived),
          archivedAt: Value(archived ? (at ?? DateTime.now()) : null),
          updatedAt: Value(DateTime.now()),
        ));
  }

  @override
  Future<void> deleteItemsAndBatches(List<String> itemIds) {
    return db.transaction(() async {
      await (db.delete(db.batches)..where((t) => t.itemId.isIn(itemIds))).go();
      await (db.delete(db.inventoryLogs)..where((t) => t.itemId.isIn(itemIds))).go();
      await (db.delete(db.repurchaseItems)..where((t) => t.itemId.isIn(itemIds))).go();
      await (db.delete(db.items)..where((t) => t.id.isIn(itemIds))).go();
    });
  }

  /// 清空归档（§4.8）：删除归档物品与其批次，保留库存流水历史。
  @override
  Future<void> deleteItemsKeepLogs(List<String> itemIds) {
    return db.transaction(() async {
      await (db.delete(db.batches)..where((t) => t.itemId.isIn(itemIds))).go();
      await (db.delete(db.repurchaseItems)..where((t) => t.itemId.isIn(itemIds))).go();
      await (db.delete(db.items)..where((t) => t.id.isIn(itemIds))).go();
    });
  }

  // ---------- 批次 ----------
  @override
  Stream<List<Batch>> watchBatches() => db.select(db.batches).watch();

  @override
  Future<List<Batch>> getBatchesOfItems(List<String> itemIds) =>
      (db.select(db.batches)..where((t) => t.itemId.isIn(itemIds))).get();

  @override
  Future<Batch?> getBatch(String id) =>
      (db.select(db.batches)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<void> insertBatch(BatchesCompanion b) =>
      db.into(db.batches).insert(b, mode: InsertMode.insertOrReplace);

  @override
  Future<void> updateBatch(BatchesCompanion b) => db.update(db.batches).write(b);

  @override
  Future<void> deleteBatches(List<String> batchIds) =>
      (db.delete(db.batches)..where((t) => t.id.isIn(batchIds))).go();

  @override
  Future<void> applyDeductions(List<BatchDeduction> deductions) {
    return db.batch((b) {
      for (final d in deductions) {
        b.update(db.batches,
            BatchesCompanion(remainingQuantity: Value(d.batch.remainingQuantity - d.amount)),
            where: (t) => t.id.equals(d.batch.id));
      }
    });
  }

  @override
  Future<void> setImagePath(String batchId, String? path) {
    return (db.update(db.batches)..where((t) => t.id.equals(batchId)))
        .write(BatchesCompanion(imagePath: Value(path)));
  }

  // ---------- 流水 ----------
  @override
  Stream<List<InventoryLog>> watchLogs() {
    return (db.select(db.inventoryLogs)
          ..orderBy([(u) => OrderingTerm.desc(u.createdAt)]))
        .watch();
  }

  @override
  Future<List<InventoryLog>> getLogs({int limit = 50, int offset = 0}) {
    return (db.select(db.inventoryLogs)
          ..orderBy([(u) => OrderingTerm.desc(u.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  @override
  Future<void> insertLogs(List<InventoryLogsCompanion> logs) =>
      db.batch((b) => b.insertAll(db.inventoryLogs, logs));

  @override
  Future<void> deleteLog(String logId) =>
      (db.delete(db.inventoryLogs)..where((t) => t.id.equals(logId))).go();

  // ---------- 回购 ----------
  @override
  Stream<List<RepurchaseItem>> watchRepurchases() =>
      (db.select(db.repurchaseItems)..orderBy([(u) => OrderingTerm.desc(u.createdAt)])).watch();

  @override
  Future<void> upsertRepurchase(RepurchaseItemsCompanion r) =>
      db.into(db.repurchaseItems).insert(r, mode: InsertMode.insertOrReplace);

  @override
  Future<void> deleteRepurchase(String id) =>
      (db.delete(db.repurchaseItems)..where((t) => t.id.equals(id))).go();

  @override
  Future<List<String>> pendingDeleteIds() async {
    final raw = await getSetting('pending_deletes');
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }

  // ---------- 设置 ----------
  @override
  Future<String?> getSetting(String key) async {
    final row = await (db.select(db.settingsEntries)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<Map<String, String>> getAllSettings() async {
    final rows = await db.select(db.settingsEntries).get();
    return {for (final r in rows) r.key: r.value};
  }

  @override
  Future<void> setSetting(String key, String value) =>
      db.into(db.settingsEntries).insert(
            SettingsEntriesCompanion.insert(key: key, value: value),
            mode: InsertMode.insertOrReplace,
          );

  @override
  Future<void> setSettings(Map<String, String> entries) => db.batch((b) {
        for (final e in entries.entries) {
          b.insert(
            db.settingsEntries,
            SettingsEntriesCompanion.insert(key: e.key, value: e.value),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

  @override
  Future<void> replaceAllData({
    required List<CategoriesCompanion> categories,
    required List<StorageLocationsCompanion> locations,
    required List<ItemsCompanion> items,
    required List<BatchesCompanion> batches,
    required List<InventoryLogsCompanion> logs,
    required List<RepurchaseItemsCompanion> repurchases,
  }) {
    return db.replaceAllData(
      categoryRows: categories,
      locationRows: locations,
      itemRows: items,
      batchRows: batches,
      logRows: logs,
      repurchaseRows: repurchases,
    );
  }
}
