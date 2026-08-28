import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    StorageLocations,
    Items,
    Batches,
    InventoryLogs,
    RepurchaseItems,
    SettingsEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );

  /// 备份恢复用：单事务内清空并重写全部业务表。
  Future<void> replaceAllData({
    required List<CategoriesCompanion> categoryRows,
    required List<StorageLocationsCompanion> locationRows,
    required List<ItemsCompanion> itemRows,
    required List<BatchesCompanion> batchRows,
    required List<InventoryLogsCompanion> logRows,
    required List<RepurchaseItemsCompanion> repurchaseRows,
  }) {
    return transaction(() async {
      await batch((b) {
        b.deleteAll(categories);
        b.deleteAll(storageLocations);
        b.deleteAll(items);
        b.deleteAll(batches);
        b.deleteAll(inventoryLogs);
        b.deleteAll(repurchaseItems);
      });
      await batch((b) {
        b.insertAll(categories, categoryRows, mode: InsertMode.insertOrReplace);
        b.insertAll(storageLocations, locationRows, mode: InsertMode.insertOrReplace);
        b.insertAll(items, itemRows, mode: InsertMode.insertOrReplace);
        b.insertAll(batches, batchRows, mode: InsertMode.insertOrReplace);
        b.insertAll(inventoryLogs, logRows, mode: InsertMode.insertOrReplace);
        b.insertAll(repurchaseItems, repurchaseRows, mode: InsertMode.insertOrReplace);
      });
    });
  }
}

/// 打开数据库连接（移动端 NativeDatabase；测试可传内存执行器）。
AppDatabase openAppDatabase(File dbFile) {
  return AppDatabase(LazyDatabase(() async => NativeDatabase.createInBackground(dbFile)));
}
