import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warmpantry/core/constants/app_constants.dart';
import 'package:warmpantry/core/utils/formatters.dart';
import 'package:warmpantry/data/database/app_database.dart';
import 'package:warmpantry/data/services/notification_service.dart';
import 'package:warmpantry/providers/settings_provider.dart';

Item mkItem({String id = 'i1', String name = '酸奶', bool archived = false, bool reminder = true}) {
  return Item(
    id: id,
    name: name,
    categoryId: 'c1',
    isConsumable: true,
    reminderEnabled: reminder,
    isArchived: archived,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
    archivedAt: null,
  );
}

Batch mkBatch({
  required String itemId,
  double remaining = 5,
  DateTime? expiryDate,
  DateTime? openedAt,
  int? shelfDays,
}) {
  return Batch(
    id: newId(),
    itemId: itemId,
    expiryDate: expiryDate,
    openedAt: openedAt,
    openShelfLifeDays: shelfDays,
    locationId: null,
    initialQuantity: 5,
    remainingQuantity: remaining,
    unit: '盒',
    notes: null,
    purchasePrice: null,
    purchaseDate: null,
    imagePath: null,
    batchLabel: 'B',
    createdAt: DateTime(2026, 8, 1),
  );
}

void main() {
  final now = DateTime(2026, 8, 26, 9);

  test('每日摘要：24 小时内到期在标题强化', () {
    final items = [mkItem()];
    final batches = [mkBatch(itemId: 'i1', expiryDate: DateTime(2026, 8, 27))];
    final c = buildSummaryContent(
      forDay: now,
      items: items,
      batches: batches,
      recentLogs: const [],
      warningDays: 3,
    );
    expect(c.title, contains('1 件今天就到期'));
    expect(c.body, contains('已过期 0 件'));
    expect(c.body, contains('酸奶'));
  });

  test('物品级提醒开关关闭后不进入摘要（§4.9）', () {
    final items = [mkItem(reminder: false)];
    final batches = [mkBatch(itemId: 'i1', expiryDate: DateTime(2026, 8, 27))];
    final c = buildSummaryContent(
      forDay: now,
      items: items,
      batches: batches,
      recentLogs: const [],
      warningDays: 3,
    );
    expect(c.title, '临期摘要');
    expect(c.body, contains('临期 0 件'));
  });

  test('归档物品与余量为 0 的批次不进入摘要', () {
    final items = [mkItem(archived: true)];
    final batches = [mkBatch(itemId: 'i1', expiryDate: DateTime(2026, 8, 27), remaining: 0)];
    final c = buildSummaryContent(
      forDay: now,
      items: items,
      batches: batches,
      recentLogs: const [],
      warningDays: 3,
    );
    expect(c.body, contains('临期 0 件'));
  });

  test('周日自动切换周报口径（§4.9）', () {
    // 2026-08-30 是周日
    final sunday = DateTime(2026, 8, 30, 21);
    final items = [mkItem()];
    final batches = [
      mkBatch(itemId: 'i1', expiryDate: DateTime(2026, 8, 31)),
      mkBatch(itemId: 'i1', expiryDate: DateTime(2026, 9, 1), remaining: 3),
    ];
    final logs = [
      InventoryLog(
        id: 'l1',
        itemId: 'i1',
        batchId: null,
        type: LogTypes.consume,
        quantity: 2,
        unit: '盒',
        locationText: null,
        source: LogSources.manual,
        note: null,
        createdAt: sunday.subtract(const Duration(days: 1)),
      ),
    ];
    final c = buildSummaryContent(
      forDay: sunday,
      items: items,
      batches: batches,
      recentLogs: logs,
      warningDays: 3,
    );
    expect(c.title, contains('本周小结'));
    expect(c.body, contains('本周消耗 1 件'));
    expect(c.body, contains('归档 0 件'));
  });

  test('settingsFromMap：KV → 类型化设置', () {
    final s = settingsFromMap({
      SettingKeys.themeMode: 'dark',
      SettingKeys.nickname: '阿仓',
      SettingKeys.expiryWarningDays: '5',
      SettingKeys.lowRemainingPercent: '30',
      SettingKeys.onboardingDone: '1',
      SettingKeys.summaryHour: '20',
      SettingKeys.summaryMinute: '15',
      SettingKeys.bellReadDate: '2026-8-28',
      SettingKeys.lastBackupOk: '0',
      SettingKeys.lastBackupError: '磁盘已满',
    });
    expect(s.themeMode, ThemeMode.dark);
    expect(s.nickname, '阿仓');
    expect(s.expiryWarningDays, 5);
    expect(s.lowRemainingPercent, 30);
    expect(s.onboardingDone, isTrue);
    expect(s.summaryHour, 20);
    expect(s.summaryMinute, 15);
    expect(s.bellReadDate, DateTime(2026, 8, 28));
    expect(s.lastBackupOk, isFalse);
    expect(s.lastBackupError, '磁盘已满');
  });

  test('settingsFromMap：空表给默认值', () {
    final s = settingsFromMap(const {});
    expect(s.themeMode, ThemeMode.system);
    expect(s.nickname, SettingDefaults.nickname);
    expect(s.expiryWarningDays, SettingDefaults.expiryWarningDays);
    expect(s.lowRemainingPercent, SettingDefaults.lowRemainingPercent);
    expect(s.onboardingDone, isFalse);
  });
}
