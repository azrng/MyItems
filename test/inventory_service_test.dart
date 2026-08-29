import 'package:flutter_test/flutter_test.dart';
import 'package:warmpantry/core/constants/app_constants.dart';
import 'package:warmpantry/core/utils/formatters.dart';
import 'package:warmpantry/data/database/app_database.dart';
import 'package:warmpantry/data/services/inventory_service.dart';

/// 构造 drift 行对象（纯数据类，无需真实数据库）。
Item mkItem({
  String id = 'i1',
  String name = '全麦吐司',
  bool archived = false,
  bool consumable = true,
  DateTime? createdAt,
}) {
  final t = createdAt ?? DateTime(2026, 8, 1);
  return Item(
    id: id,
    name: name,
    categoryId: 'c1',
    isConsumable: consumable,
    reminderEnabled: true,
    isArchived: archived,
    createdAt: t,
    updatedAt: t,
    archivedAt: null,
  );
}

Batch mkBatch({
  String id = 'b1',
  String itemId = 'i1',
  DateTime? expiryDate,
  DateTime? openedAt,
  int? openShelfLifeDays,
  double initial = 10,
  double remaining = 10,
  String unit = '袋',
  DateTime? createdAt,
}) {
  final t = createdAt ?? DateTime(2026, 8, 1);
  return Batch(
    id: id,
    itemId: itemId,
    expiryDate: expiryDate,
    openedAt: openedAt,
    openShelfLifeDays: openShelfLifeDays,
    locationId: null,
    initialQuantity: initial,
    remainingQuantity: remaining,
    unit: unit,
    notes: null,
    purchasePrice: null,
    purchaseDate: null,
    imagePath: null,
    batchLabel: '20260801',
    createdAt: t,
  );
}

InventoryLog mkLog({
  required String type,
  required DateTime at,
  String itemId = 'i1',
  String? batchId,
  double quantity = 1,
  String unit = '袋',
}) {
  return InventoryLog(
    id: newId(),
    itemId: itemId,
    batchId: batchId,
    type: type,
    quantity: quantity,
    unit: unit,
    locationText: null,
    source: LogSources.manual,
    note: null,
    createdAt: at,
  );
}

void main() {
  final now = DateTime(2026, 8, 28, 15, 0);

  group('InventoryService.sortFifo（§4.3 FIFO 消耗落点）', () {
    test('按有效到期日升序，开封限期参与计算', () {
      final batches = [
        mkBatch(id: 'b-long', expiryDate: DateTime(2026, 9, 30)),
        mkBatch(
            id: 'b-open',
            expiryDate: DateTime(2026, 9, 30),
            openedAt: DateTime(2026, 8, 25),
            openShelfLifeDays: 4), // 有效到期 08-29
        mkBatch(id: 'b-soon', expiryDate: DateTime(2026, 8, 30)),
        mkBatch(id: 'b-zero', expiryDate: DateTime(2026, 8, 29), remaining: 0),
      ];
      final fifo = InventoryService.sortFifo(batches, now);
      expect(fifo.map((b) => b.id).toList(),
          ['b-open', 'b-soon', 'b-long'], reason: '扣尽的批次不参与排序');
    });

    test('无期限批次排最后', () {
      final batches = [
        mkBatch(id: 'b-none'),
        mkBatch(id: 'b-soon', expiryDate: DateTime(2026, 8, 30)),
      ];
      expect(InventoryService.sortFifo(batches, now).map((b) => b.id).toList(),
          ['b-soon', 'b-none']);
    });
  });

  group('统计口径（§4.11）', () {
    test('今日消耗笔数（同物品多笔不合并）', () {
      final logs = [
        mkLog(type: LogTypes.consume, at: now.subtract(const Duration(hours: 1))),
        mkLog(type: LogTypes.consume, at: now.subtract(const Duration(hours: 2))),
        mkLog(type: LogTypes.intake, at: now.subtract(const Duration(hours: 1))),
        mkLog(
            type: LogTypes.consume,
            at: now.subtract(const Duration(days: 1))),
      ];
      expect(InventoryService.todayConsumeCount(logs, now), 2);
    });

    test('本周消耗柱状图（周一 → 周日对齐）', () {
      // 2026-08-28 是周五；本周一为 08-24
      final logs = [
        mkLog(type: LogTypes.consume, at: now), // 周五（今天）第 1 笔
        mkLog(type: LogTypes.consume, at: now), // 周五（今天）第 2 笔
        mkLog(
            type: LogTypes.consume,
            at: DateTime(2026, 8, 24, 9)), // 本周一
        mkLog(
            type: LogTypes.consume,
            at: DateTime(2026, 8, 23, 20)), // 上周日：不计入本周
      ];
      final bars = InventoryService.weeklyConsume(logs, now);
      expect(bars.length, 7);
      expect(bars.first, 1, reason: '本周一');
      expect(bars[4], 2, reason: '周五 = 今天');
      expect(bars[6], 0, reason: '周日尚未到来');
      expect(bars[1] + bars[2] + bars[3] + bars[5], 0);
    });

    test('连续记录天数：中断清零、当天无记录看昨天', () {
      final logs = [
        mkLog(type: LogTypes.intake, at: now),
        mkLog(type: LogTypes.consume, at: now.subtract(const Duration(days: 1))),
        mkLog(type: LogTypes.consume, at: now.subtract(const Duration(days: 2))),
        // 3 天前中断
        mkLog(type: LogTypes.intake, at: now.subtract(const Duration(days: 5))),
      ];
      expect(InventoryService.streakDays(logs, now), 3);
    });

    test('当天与昨天都无流水 → 0', () {
      final logs = [
        mkLog(type: LogTypes.intake, at: now.subtract(const Duration(days: 3))),
      ];
      expect(InventoryService.streakDays(logs, now), 0);
    });
  });

  group('多批次扣尽判定', () {
    test('全部扣尽时无 activeBatches', () {
      final batches = [mkBatch(remaining: 0, initial: 5)];
      final fifo = InventoryService.sortFifo(batches, now);
      expect(fifo, isEmpty);
    });
  });
}
