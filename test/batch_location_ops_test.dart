import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:warmpantry/core/utils/result.dart';
import 'package:warmpantry/data/database/app_database.dart';
import 'package:warmpantry/data/repositories/inventory_repository.dart';
import 'package:warmpantry/data/services/inventory_service.dart';

/// T013 修复的真实链路 smoke：批次级用完 / 批次删除 / 位置删除（含占用迁移）。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late DriftInventoryRepository repo;
  late InventoryService svc;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('warmpantry_ops_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'test.sqlite'))));
    repo = DriftInventoryRepository(db);
    svc = InventoryService(repo);
    await repo.insertLocation(StorageLocationsCompanion.insert(
      id: 'loc-a',
      name: '位置A',
      region: const Value('厨房区域'),
      sortOrder: const Value(1),
    ));
    await repo.insertLocation(StorageLocationsCompanion.insert(
      id: 'loc-b',
      name: '位置B',
      region: const Value('厨房区域'),
      sortOrder: const Value(2),
    ));
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// 建一个带 [n] 个批次（每批 1 件）的在库物品，批次都存放在 loc-a。
  Future<String> seedItemWithBatches(int n) async {
    final r = await svc.saveIntake(
      name: '测试物品',
      categoryId: 'c1',
      isConsumable: true,
      reminderEnabled: true,
      locationId: 'loc-a',
      quantity: 1,
      unit: '件',
    );
    final item = r.dataOrNull!;
    for (var i = 1; i < n; i++) {
      await svc.saveIntake(
        existingItemId: item.id,
        name: item.name,
        categoryId: item.categoryId,
        isConsumable: item.isConsumable,
        reminderEnabled: item.reminderEnabled,
        locationId: 'loc-a',
        quantity: 1,
        unit: '件',
      );
    }
    return item.id;
  }

  test('finishBatch 只清零指定批次，其他批次与在库状态不受影响', () async {
    final itemId = await seedItemWithBatches(3);
    final batches = await repo.getBatchesOfItems([itemId])
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final r = await svc.finishBatch(batchId: batches.first.id);
    expect(r.dataOrNull, isNotNull);
    expect(r.dataOrNull!.qty, 1);
    expect(r.dataOrNull!.logId, isNotNull);

    final after = await repo.getBatchesOfItems([itemId]);
    expect(
        after
            .firstWhere((b) => b.id == batches.first.id)
            .remainingQuantity,
        0);
    expect(
        after.where((b) => b.id != batches.first.id).every(
            (b) => b.remainingQuantity == 1),
        isTrue);
    expect((await repo.getItem(itemId))!.isArchived, isFalse);
  });

  test('finishBatch 清零最后批次自动归档，undoConsume 回滚归档与余量', () async {
    final itemId = await seedItemWithBatches(1);
    final batch = (await repo.getBatchesOfItems([itemId])).first;

    final r = await svc.finishBatch(batchId: batch.id);
    expect((await repo.getItem(itemId))!.isArchived, isTrue);

    final undo = await svc.undoConsume(r.dataOrNull!.logId!);
    expect(undo.isFailure, isFalse);
    expect((await repo.getItem(itemId))!.isArchived, isFalse);
    final restored = await repo.getBatch(batch.id);
    expect(restored!.remainingQuantity, 1);
  });

  test('deleteBatch 物理删除批次并留痕，删空后物品自动归档', () async {
    final itemId = await seedItemWithBatches(2);
    final batches = await repo.getBatchesOfItems([itemId])
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    await svc.deleteBatch(batchId: batches.first.id);
    var after = await repo.getBatchesOfItems([itemId]);
    expect(after.length, 1);
    expect((await repo.getItem(itemId))!.isArchived, isFalse);

    await svc.deleteBatch(batchId: after.first.id);
    after = await repo.getBatchesOfItems([itemId]);
    expect(after, isEmpty);
    expect((await repo.getItem(itemId))!.isArchived, isTrue);
  });

  test('deleteLocation 无占用直接删除', () async {
    final r = await svc.deleteLocation(locationId: 'loc-b');
    expect(r.isFailure, isFalse);
    expect(await repo.getLocation('loc-b'), isNull);
  });

  test('deleteLocation 有占用未给目标位置时拒绝删除', () async {
    await seedItemWithBatches(1);
    final r = await svc.deleteLocation(locationId: 'loc-a');
    expect(r.isFailure, isTrue);
    expect(await repo.getLocation('loc-a'), isNotNull);
  });

  test('deleteLocation 有占用时批次移入目标位置，位置删除且悬空引用置空', () async {
    final itemId = await seedItemWithBatches(2);
    // 耗尽其中一个批次：验证零余量批次不迁移、仅置空
    final batches = await repo.getBatchesOfItems([itemId])
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await svc.finishBatch(batchId: batches.first.id);

    final r = await svc.deleteLocation(
        locationId: 'loc-a', moveToLocationId: 'loc-b');
    expect(r.isFailure, isFalse);
    expect(await repo.getLocation('loc-a'), isNull);

    final after = await repo.getBatchesOfItems([itemId]);
    expect(
        after
            .where((b) => b.remainingQuantity > 0)
            .every((b) => b.locationId == 'loc-b'),
        isTrue);
    expect(
        after
            .where((b) => b.remainingQuantity == 0)
            .every((b) => b.locationId == null),
        isTrue);
    expect((await repo.getItem(itemId))!.lastLocationId, isNull);
  });
}
