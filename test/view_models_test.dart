import 'package:flutter_test/flutter_test.dart';
import 'package:warmpantry/core/constants/app_constants.dart';
import 'package:warmpantry/core/utils/formatters.dart';
import 'package:warmpantry/data/database/app_database.dart';
import 'package:warmpantry/providers/view_models.dart';

Item item({bool archived = false, DateTime? archivedAt, DateTime? createdAt}) {
  final t = createdAt ?? DateTime(2026, 8, 1, 9);
  return Item(
    id: 'i1',
    name: '鲜牛奶',
    categoryId: 'c1',
    isConsumable: true,
    reminderEnabled: true,
    isArchived: archived,
    archivedAt: archivedAt,
    createdAt: t,
    updatedAt: t,
  );
}

Batch batch({
  String id = 'b1',
  double initial = 12,
  double remaining = 12,
  DateTime? expiryDate,
  DateTime? openedAt,
  int? shelfDays,
  String unit = '盒',
}) {
  return Batch(
    id: id,
    itemId: 'i1',
    expiryDate: expiryDate,
    openedAt: openedAt,
    openShelfLifeDays: shelfDays,
    locationId: 'l1',
    initialQuantity: initial,
    remainingQuantity: remaining,
    unit: unit,
    notes: null,
    purchasePrice: null,
    purchaseDate: null,
    imagePath: null,
    batchLabel: 'B1',
    createdAt: DateTime(2026, 8, 1, 9),
  );
}

void main() {
  final now = DateTime(2026, 8, 28, 12);

  group('ViewComposer.composeItem', () {
    test('聚合余量与百分比，primaryBatch 取最早效期', () {
      final v = ViewComposer.composeItem(
        item: item(),
        allBatches: [
          batch(expiryDate: DateTime(2026, 9, 1), remaining: 6, initial: 12),
          batch(
              id: 'b2',
              expiryDate: DateTime(2026, 8, 30),
              remaining: 3,
              initial: 6),
        ],
        now: now,
        warningDays: 3,
        lowRemainingPercent: 25,
      );
      expect(v, isNotNull);
      expect(v!.totalRemaining, 9);
      expect(v.totalInitial, 18);
      expect(v.percent, 50);
      expect(v.primaryBatch!.id, 'b2', reason: '最早到期批次在前');
      expect(v.lowRemaining, isFalse);
    });

    test('无批次且未归档 → 返回 null（防御）', () {
      final v = ViewComposer.composeItem(
        item: item(),
        allBatches: [],
        now: now,
        warningDays: 3,
        lowRemainingPercent: 25,
      );
      expect(v, isNull);
    });

    test('开封超限参与临期', () {
      final v = ViewComposer.composeItem(
        item: item(),
        allBatches: [
          batch(
            expiryDate: DateTime(2026, 12, 30),
            openedAt: DateTime(2026, 8, 10),
            shelfDays: 4, // 08-14 超限
            remaining: 5,
            initial: 10,
          ),
        ],
        now: now,
        warningDays: 3,
        lowRemainingPercent: 25,
      );
      final entry = ViewComposer.toExpiringEntry(v!, now);
      expect(entry, isNotNull);
      expect(entry!.openOverdue, isTrue);
    });
  });

  group('归档统计（§4.4）', () {
    test('累计 / 平均周期 / 本月归档', () {
      final items = [
        item(archived: true, archivedAt: DateTime(2026, 8, 31, 12)), // 30 天
        item(archived: true, archivedAt: DateTime(2026, 7, 31, 12), createdAt: DateTime(2026, 7, 1, 9)), // 30 天
      ];
      final stats = ViewComposer.archiveStats(items, DateTime(2026, 8, 31));
      expect(stats.total, 2);
      expect(stats.avgDays, 30);
      expect(stats.month, 1);
    });
  });

  group('月度消耗统计（§5.4）', () {
    test('本月笔数 / 最常消耗 / 节流成就', () {
      InventoryLog logOf(String type, DateTime at, String itemId) => InventoryLog(
            id: newId(),
            itemId: itemId,
            batchId: null,
            type: type,
            quantity: 1,
            unit: '盒',
            locationText: null,
            source: LogSources.manual,
            note: null,
            createdAt: at,
          );
      final now = DateTime(2026, 8, 31, 20);
      final logs = [
        logOf(LogTypes.consume, now.subtract(const Duration(hours: 1)), 'milk'),
        logOf(LogTypes.consume, now.subtract(const Duration(hours: 2)), 'milk'),
        logOf(LogTypes.consume, now.subtract(const Duration(hours: 3)), 'bread'),
        logOf(LogTypes.consume, DateTime(2026, 7, 15), 'milk'),
        logOf(LogTypes.consume, DateTime(2026, 7, 16), 'milk'),
        logOf(LogTypes.consume, DateTime(2026, 7, 17), 'milk'),
      ];
      final stats = ViewComposer.monthlyConsumeStats(
        logs.map((l) => LogView(l, null)).toList(),
        {},
        now,
      );
      expect(stats.monthCount, 3);
      expect(stats.topItem, '已删除物品');
      expect(stats.thrift, 0, reason: '上月 3 笔 - 本月 3 笔 = 0');
    });
  });
}
