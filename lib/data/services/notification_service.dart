import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/app_constants.dart';
import '../../core/utils/expiry_helper.dart';
import '../../core/utils/formatters.dart';
import '../database/app_database.dart';

/// 聚合摘要内容（纯函数，可测）。
class SummaryContent {
  final String title;
  final String body;
  const SummaryContent(this.title, this.body);
}

/// 本地通知（requirement.md §4.9）：
/// 摘要 = App 内预计算 + 系统定时投递；每次启动/数据变更/修改设置后重挂未来 7 天。
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'daily_summary';
  static const _channelName = '临期每日摘要';
  static const _baseId = 100;

  Future<void> init({
    required void Function(String payload) onNotificationTap,
  }) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // 频道随通知详情自动注册，无需单独 createChannel
    await _plugin.initialize(
      settings: const InitializationSettings(
        // 通知小图标须指向工程内实际存在的资源；App 图标是 @drawable/app_icon，没有 mipmap/ic_launcher
        android: AndroidInitializationSettings('app_icon'),
      ),
      onDidReceiveNotificationResponse: (r) => onNotificationTap(r.payload ?? ''),
    );
    _ready = true;
  }

  /// 用户主动开启提醒 / 点铃铛时申请 POST_NOTIFICATIONS（拒绝后不再反复弹）。
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> _exactAvailable() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestExactAlarmsPermission();
    if (granted == true) return true;
    return false;
  }

  /// 重挂未来 7 天摘要（周日用周报口径）。数据只会在 App 内变化，预计算不过时。
  Future<void> rescheduleSummaries({
    required DateTime now,
    required int hour,
    required int minute,
    required SummaryContent Function(DateTime forDay) build,
  }) async {
    if (!_ready) return;
    await cancelAll();
    final useExact = await _exactAvailable();
    for (var i = 0; i < 7; i++) {
      final day = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (day.isBefore(now)) continue;
      final c = build(day);
      final tzTime = _tz(day);
      await _plugin.zonedSchedule(
        id: _baseId + i,
        title: c.title,
        body: c.body,
        scheduledDate: tzTime,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '每天一条临期与已过期聚合摘要',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        androidScheduleMode: useExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '/expiring',
      );
    }
  }

  tz.TZDateTime _tz(DateTime t) {
    final local = tz.local;
    return tz.TZDateTime.from(t, local);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

/// 摘要内容预计算（周报口径见 §4.9：周日 21:00 当日摘要自动切换）。
SummaryContent buildSummaryContent({
  required DateTime forDay,
  required List<Item> items,
  required List<Batch> batches,
  required List<InventoryLog> recentLogs,
  required int warningDays,
}) {
  final byId = {for (final i in items) i.id: i};
  var expiring = 0, expired = 0, dueToday = 0;
  final urgentNames = <String>[];

  for (final b in batches) {
    final item = byId[b.itemId];
    if (item == null || item.isArchived || !item.reminderEnabled) continue;
    if (b.remainingQuantity <= 0) continue;
    final eff = ExpiryHelper.effectiveExpiry(
        expiryDate: b.expiryDate, openedAt: b.openedAt, openShelfLifeDays: b.openShelfLifeDays);
    final d = ExpiryHelper.daysUntil(eff, forDay);
    if (d < 0) {
      expired++;
    } else if (d == 0 || d == 1) {
      expiring++;
      dueToday++;
      if (urgentNames.length < 3) urgentNames.add(item.name);
    } else if (d <= warningDays) {
      expiring++;
      if (urgentNames.length < 3) urgentNames.add(item.name);
    }
  }

  final isSunday = forDay.weekday == DateTime.sunday;
  if (isSunday) {
    final weekAgo = forDay.subtract(const Duration(days: 7));
    final consumed = recentLogs
        .where((l) => l.type == LogTypes.consume && l.createdAt.isAfter(weekAgo))
        .length;
    final archived = recentLogs
        .where((l) => l.type == LogTypes.archive && l.createdAt.isAfter(weekAgo))
        .length;
    // 挽救口径（v1）：近 7 天被消耗且有效到期日仍未过的批次
    final saved = batches
        .where((b) =>
            b.remainingQuantity <= 0 &&
            recentLogs.any((l) =>
                l.batchId == b.id &&
                l.type == LogTypes.consume &&
                l.createdAt.isAfter(weekAgo)) &&
            (ExpiryHelper.effectiveExpiry(
                    expiryDate: b.expiryDate,
                    openedAt: b.openedAt,
                    openShelfLifeDays: b.openShelfLifeDays)
                ?.isBefore(forDay) ==
                false))
        .length;
    return SummaryContent(
      '📚 本周小结',
      '本周消耗 $consumed 件 · 归档 $archived 件 · 挽救 $saved 件临期',
    );
  }

  final head = dueToday > 0 ? '⚠️ $dueToday 件今天就到期' : '临期摘要';
  final names = urgentNames.isEmpty ? '' : '：${urgentNames.join('、')}';
  final body = '临期 $expiring 件 · 已过期 $expired 件$names（${Fmt.clock(
          SettingDefaults.summaryHour, SettingDefaults.summaryMinute)} 提醒可在我的-提醒设置调整）';
  // 标题只承载强化信息，body 带明细
  return SummaryContent(head, body);
}
