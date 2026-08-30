import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Batch, Column;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/formatters.dart';
import '../core/utils/result.dart';
import '../data/database/app_database.dart';
import '../data/services/inventory_service.dart';
import '../data/services/backup_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/sync_service.dart';
import '../data/services/webdav_client.dart';
import 'core_providers.dart';
import 'inventory_providers.dart';
import 'settings_provider.dart';

/// 命令编排层：UI → Actions → Service，成功后统一挂后置钩子
/// （触感反馈 / 防抖自动备份 / 重挂通知 / 刷新派生状态）。
class InventoryActions {
  final Ref _ref;
  Timer? _backupDebounce;

  InventoryActions(this._ref);

  InventoryService get _svc =>
      InventoryService(_ref.read(inventoryRepositoryProvider));
  BackupService get _backup => _ref.read(backupServiceProvider);
  CloudSyncService get _cloudSync => _ref.read(cloudSyncServiceProvider);
  SettingsController get _settings => _ref.read(settingsProvider.notifier);

  Future<Result<T>> _afterChange<T>(Future<Result<T>> action,
      {bool haptic = true}) async {
    final result = await action;
    if (result is Success<T>) {
      if (haptic) HapticFeedback.lightImpact();
      _onDataChanged();
    }
    return result;
  }

  /// 数据变更后置钩子：30 秒防抖备份 + 重挂摘要通知。
  void _onDataChanged() {
    _backupDebounce?.cancel();
    _backupDebounce = Timer(UndoWindows.backupDebounce, () {
      _runAutoBackup();
    });
    _rescheduleNotifications();
  }

  Future<void> _runAutoBackup() async {
    final s = _ref.read(settingsProvider);
    if (!s.autoBackupEnabled) return;
    await _backup.exportBackupSafely(kind: 'auto');
    await _settings.refreshBackupStatus();
    // 备份后孤儿扫描：先备份后清理，顺序不可反（§4.10）
    await _sweepOrphanImages();
    await _autoCloudPush();
  }

  /// 坚果云跟随推送：用户开启「自动备份同时推送云端」后，
  /// 本地自动备份成功的同时上传一份到云端；失败只记状态，不打断本地链路。
  Future<void> _autoCloudPush() async {
    final s = _ref.read(settingsProvider);
    if (!s.cloudSyncAutoPush) return;
    await pushCloudBackup();
  }

  Future<void> _sweepOrphanImages() async {
    final batches =
        await _ref.read(inventoryRepositoryProvider).watchBatches().first;
    final referenced =
        batches.map((b) => b.imagePath).whereType<String>().toSet();
    await _ref.read(imageServiceProvider).removeOrphans(referenced);
  }

  void _rescheduleNotifications() {
    final s = _ref.read(settingsProvider);
    if (!s.dailySummaryEnabled) return;
    final items = _ref.read(itemsProvider).value ?? const <Item>[];
    final batches = _ref.read(batchesProvider).value ?? const <Batch>[];
    final logs = _ref.read(logsProvider).value ?? const <InventoryLog>[];
    _ref.read(notificationServiceProvider).rescheduleSummaries(
          now: DateTime.now(),
          hour: s.summaryHour,
          minute: s.summaryMinute,
          build: (day) => buildSummaryContent(
            forDay: day,
            items: items,
            batches: batches,
            recentLogs: logs,
            warningDays: s.expiryWarningDays,
          ),
        );
  }

  /// 提醒设置变更后立即重挂摘要闹钟；关闭开关时清掉已挂闹钟，避免到点仍响。
  Future<void> rescheduleReminderSummaries() async {
    final s = _ref.read(settingsProvider);
    if (!s.dailySummaryEnabled) {
      await _ref.read(notificationServiceProvider).cancelAll();
      return;
    }
    _rescheduleNotifications();
  }

  /// 启动钩子：冷启动清扫待删残留、每日首次启动补备份、重挂通知。
  Future<void> onAppStart() async {
    await _svc.purgePendingDeletes();
    _ref.invalidate(pendingDeletesProvider);
    final s = _ref.read(settingsProvider);
    if (s.onboardingDone && s.autoBackupEnabled) {
      final backed = await _backup.autoBackupIfNeeded();
      // 每日首次补备份的这一次同样跟随云端推送
      if (backed) await _autoCloudPush();
    }
    _rescheduleNotifications();
  }

  // ============ 录入 / 编辑 ============

  Future<Result<Item>> saveIntake({
    String? existingItemId,
    required String name,
    String? spec,
    required String categoryId,
    String? icon,
    required bool isConsumable,
    required bool reminderEnabled,
    required String locationId,
    required double quantity,
    required String unit,
    DateTime? expiryDate,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? notes,
    String? pickedImagePath,
    String? source,
  }) async {
    final imagePath =
        await _ref.read(imageServiceProvider).importPicked(pickedImagePath);
    final result = _afterChange(_svc.saveIntake(
      existingItemId: existingItemId,
      name: name,
      spec: spec,
      categoryId: categoryId,
      icon: icon,
      isConsumable: isConsumable,
      reminderEnabled: reminderEnabled,
      locationId: locationId,
      quantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate,
      notes: notes,
      imagePath: imagePath,
      source: source,
    ));
    await _settings.setLastUsedUnit(unit);
    return result;
  }

  Future<List<Item>> findSameName(String name) => _svc.findSameName(name);

  /// 编辑保存（§4.7）：更新主档 + 主批次，不含余量变化。
  Future<Result<void>> saveEdits({
    required String itemId,
    required String batchId,
    required String name,
    String? spec,
    required String categoryId,
    String? icon,
    required bool isConsumable,
    required bool reminderEnabled,
    String? locationId,
    DateTime? expiryDate,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? notes,
    String? pickedImagePath,
    String? oldImageName,
  }) async {
    var imagePath = oldImageName;
    if (pickedImagePath != null) {
      final images = _ref.read(imageServiceProvider);
      imagePath = await images.replacePicked(pickedImagePath, oldImageName);
    }
    return _afterChange(_svc.saveEdits(
      itemId: itemId,
      batchId: batchId,
      name: name,
      spec: spec,
      categoryId: categoryId,
      icon: icon,
      isConsumable: isConsumable,
      reminderEnabled: reminderEnabled,
      locationId: locationId,
      expiryDate: expiryDate,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate,
      notes: notes,
      imagePath: imagePath,
    ));
  }

  // ============ 消耗 / 归档 ============

  /// 返回 (流水 id, 实际扣减量)——流水 id 供 5 秒撤销，扣减量供 toast 文案。
  Future<Result<({String? logId, double qty})?>> consume({
    required String itemId,
    required double quantity,
    required String source,
    String? note,
  }) async {
    final result = await _afterChange(_svc.consumeFifo(
        itemId: itemId, quantity: quantity, source: source, note: note));
    final data = result.dataOrNull;
    if (data == null) return const Success(null);
    final qty = data.deductions.fold<double>(0, (s, d) => s + d.amount);
    return Success((logId: data.logId, qty: qty));
  }

  Future<Result<void>> undoConsume(String logId) =>
      _afterChange(_svc.undoConsume(logId), haptic: false);

  /// 「✓ 用完」二次确认后归档，返回告别语陪伴天数。
  Future<Result<int>> finishItem(String itemId) =>
      _afterChange(_svc.finishAndArchive(itemId: itemId));

  // ============ 批次级操作 ============

  /// 批次级「✓完」：仅清零该批次，全部批次耗尽才自动归档。
  Future<Result<({String? logId, double qty})>> finishBatch(String batchId) =>
      _afterChange(_svc.finishBatch(batchId: batchId));

  /// 删除指定批次（流水留痕，物品耗尽自动归档）。
  Future<Result<void>> deleteBatch(String batchId) =>
      _afterChange(_svc.deleteBatch(batchId: batchId));

  Future<Result<void>> adjustRemaining(
          String batchId, double value, String? reason) =>
      _afterChange(_svc.adjustRemaining(
          batchId: batchId, newValue: value, reason: reason));

  Future<Result<void>> openBatch(
          String batchId, DateTime openedAt, int? shelfDays) =>
      _afterChange(_svc.openBatch(
          batchId: batchId, openedAt: openedAt, shelfLifeDays: shelfDays));

  Future<Result<void>> cancelOpen(String batchId) =>
      _afterChange(_svc.cancelOpen(batchId));

  Future<Result<void>> updateOpenInfo(
          String batchId, DateTime openedAt, int? shelfDays) =>
      _afterChange(_svc.updateOpenInfo(
          batchId: batchId, openedAt: openedAt, shelfLifeDays: shelfDays));

  Future<Result<void>> moveBatch(String batchId, String? locationId) =>
      _afterChange(_svc.moveBatch(batchId: batchId, locationId: locationId));

  /// 批量操作（§4.8，本身可逆不设撤销）。
  Future<void> changeCategory(String itemId, String categoryId) async {
    await _svc.changeCategory(itemId, categoryId);
    _onDataChanged();
  }

  Future<void> moveAllBatches(String itemId, String locationId) async {
    await _svc.moveAllBatches(itemId, locationId);
    _onDataChanged();
  }

  // ============ 删除（两段式） ============

  Future<void> deleteItems(List<String> itemIds) async {
    await _svc.softDeleteItems(itemIds);
    _ref.invalidate(pendingDeletesProvider);
    Timer(UndoWindows.deleteDebounce, () async {
      final images = await _svc.purgePendingDeletes();
      if (images.isNotEmpty) {
        // 待清理集合直接进入孤儿扫描语义：备份后统一删除
        final batches =
            await _ref.read(inventoryRepositoryProvider).watchBatches().first;
        final referenced =
            batches.map((b) => b.imagePath).whereType<String>().toSet();
        await _ref.read(imageServiceProvider).removeOrphans(referenced);
      }
      _ref.invalidate(pendingDeletesProvider);
      _onDataChanged();
    });
  }

  Future<void> undoDeleteItems(List<String> itemIds) async {
    await _svc.undoSoftDelete(itemIds);
    _ref.invalidate(pendingDeletesProvider);
  }

  /// 清空归档（§4.8）：仅清除归档物品，不动流水历史。
  Future<void> clearArchive() async {
    final items = _ref.read(itemsProvider).value ?? const <Item>[];
    final ids = items.where((i) => i.isArchived).map((i) => i.id).toList();
    if (ids.isEmpty) return;
    await _ref.read(inventoryRepositoryProvider).deleteItemsKeepLogs(ids);
    _onDataChanged();
  }

  // ============ 回购 ============

  Future<void> addToRepurchase(String itemId) async {
    await _svc.addToRepurchase(itemId);
    _onDataChanged();
  }

  Future<void> toggleRepurchase(RepurchaseItem r) async {
    await _svc.toggleRepurchaseStatus(r);
    _onDataChanged();
  }

  Future<void> removeRepurchase(String id) async {
    await _svc.removeRepurchase(id);
    _onDataChanged();
  }

  // ============ 分类 / 位置 / 引导 ============

  Future<void> seedOnboarding({required bool withLocations}) async {
    await _ref
        .read(seedServiceProvider)
        .seed(withPresetLocations: withLocations);
    await _settings.markOnboardingDone();
    _onDataChanged();
  }

  Future<void> saveCategory({
    String? id,
    required String name,
    required String icon,
    required String colorKey,
    String? description,
    required int sortOrder,
    required bool isPreset,
  }) async {
    final repo = _ref.read(inventoryRepositoryProvider);
    if (id == null) {
      await repo.insertCategory(CategoriesCompanion.insert(
        id: newId(),
        name: name,
        description: Value(description),
        icon: Value(icon),
        colorKey: Value(colorKey),
        sortOrder: Value(sortOrder),
        isPreset: Value(isPreset),
      ));
    } else {
      await repo.updateCategory(CategoriesCompanion(
        id: Value(id),
        name: Value(name),
        description: Value(description),
        icon: Value(icon),
        colorKey: Value(colorKey),
        sortOrder: Value(sortOrder),
        isPreset: Value(isPreset),
      ));
    }
    _onDataChanged();
  }

  /// 拖拽排序持久化（§5.7）。
  Future<void> saveCategoryOrder(List<Category> list) async {
    await _ref.read(inventoryRepositoryProvider).reorderCategories(
      [
        for (var i = 0; i < list.length; i++) (id: list[i].id, sortOrder: i + 1)
      ],
    );
    _onDataChanged();
  }

  Future<Result<void>> deleteCategory(String id) async {
    final repo = _ref.read(inventoryRepositoryProvider);
    final count = await repo.countItemsOfCategory(id);
    if (count > 0) {
      return Failure('该分类下还有 $count 件在库物品，不能删除');
    }
    await repo.deleteCategory(id);
    return const Success(null);
  }

  Future<void> saveLocation({
    String? id,
    required String name,
    required String region,
    required String icon,
    required int? capacity,
    required int sortOrder,
    required bool isActive,
  }) async {
    final repo = _ref.read(inventoryRepositoryProvider);
    if (id == null) {
      await repo.insertLocation(StorageLocationsCompanion.insert(
        id: newId(),
        name: name,
        region: Value(region),
        icon: Value(icon),
        capacity: Value(capacity),
        sortOrder: Value(sortOrder),
        isActive: const Value(true),
      ));
    } else {
      await repo.updateLocation(StorageLocationsCompanion(
        id: Value(id),
        name: Value(name),
        region: Value(region),
        icon: Value(icon),
        capacity: Value(capacity),
        sortOrder: Value(sortOrder),
        isActive: Value(isActive),
      ));
    }
    _onDataChanged();
  }

  Future<void> deactivateLocation(String id) async {
    await _ref.read(inventoryRepositoryProvider).deactivateLocation(id);
    _onDataChanged();
  }

  /// 删除位置：在库批次先移入 [moveToLocationId]，其余引用置空。
  Future<Result<void>> deleteLocation({
    required String locationId,
    String? moveToLocationId,
  }) => _afterChange(_svc.deleteLocation(
      locationId: locationId, moveToLocationId: moveToLocationId));

  // ============ 备份 / 恢复 / 存储 ============

  Future<File> exportNow() async {
    final f = await _backup.exportBackup(kind: 'manual');
    await _settings.refreshBackupStatus();
    _ref.invalidate(lastBackupInfoProvider);
    return f;
  }

  Future<void> restore(File zip) async {
    await _backup.restoreFromZip(zip);
    _ref.invalidate(pendingDeletesProvider);
    _onDataChanged();
  }

  Future<void> runAutoBackupNow() async {
    await _backup.exportBackupSafely(kind: 'auto');
    await _settings.refreshBackupStatus();
    await _sweepOrphanImages();
    _ref.invalidate(lastBackupInfoProvider);
  }

  Future<({int db, int images, int backups, int cache})> storageUsage() =>
      _backup.storageUsage();

  Future<void> clearCache() => _backup.clearCache();

  // ============ 坚果云 WebDAV 同步（§7.2） ============

  /// 读取已保存的坚果云凭据；账号或应用密码未配置时返回 null。
  Future<WebDavCredentials?> _savedCloudCredentials() async {
    final s = _ref.read(settingsProvider);
    if (s.cloudSyncUser.trim().isEmpty) return null;
    final token = await _ref
        .read(inventoryRepositoryProvider)
        .getSetting(SettingKeys.cloudSyncToken);
    if (token == null || token.isEmpty) return null;
    return WebDavCredentials(
        url: s.cloudSyncUrl, user: s.cloudSyncUser, token: token);
  }

  Future<void> saveCloudSyncConfig({
    required String url,
    required String user,
    String? token,
  }) async {
    await _settings.setCloudSyncConfig(url: url, user: user, token: token);
  }

  Future<void> setCloudSyncOptions({int? keepCount, bool? autoPush}) async {
    await _settings.setCloudSyncOptions(keepCount: keepCount, autoPush: autoPush);
  }

  Future<({bool ok, String message})> testCloudSync() async {
    final c = await _savedCloudCredentials();
    if (c == null) {
      return (ok: false, message: '请先保存账号与应用密码');
    }
    final r = await _cloudSync.testConnection(c);
    return (ok: r.ok, message: r.message);
  }

  /// 立即推送备份到坚果云（导出 → 上传 → 按保留数清理），并记录推送状态。
  Future<({bool ok, String message})> pushCloudBackup() async {
    final c = await _savedCloudCredentials();
    if (c == null) {
      return (ok: false, message: '请先保存账号与应用密码');
    }
    final s = _ref.read(settingsProvider);
    try {
      final entry =
          await _cloudSync.uploadBackup(c, keepCount: s.cloudSyncKeepCount);
      await _recordCloudSync(ok: true, error: '');
      return (ok: true, message: '已推送 ${entry.name}');
    } on SyncException catch (e) {
      await _recordCloudSync(ok: false, error: e.message);
      return (ok: false, message: e.message);
    } catch (e) {
      await _recordCloudSync(ok: false, error: '$e');
      return (ok: false, message: '推送失败：$e');
    }
  }

  Future<void> _recordCloudSync({required bool ok, required String error}) async {
    await _ref.read(inventoryRepositoryProvider).setSettings({
      SettingKeys.cloudSyncLastAt: DateTime.now().toIso8601String(),
      SettingKeys.cloudSyncLastOk: ok ? '1' : '0',
      SettingKeys.cloudSyncLastError: error,
    });
    await _settings.refreshCloudSyncStatus();
  }

  Future<List<CloudBackupEntry>> loadCloudBackups() async {
    final c = await _savedCloudCredentials();
    if (c == null) throw const SyncException('请先保存账号与应用密码');
    return _cloudSync.listBackups(c);
  }

  /// 从云端备份恢复：下载 → 全量覆盖导入（内含后悔药预导出）。
  Future<void> restoreCloudBackup(String name) async {
    final c = await _savedCloudCredentials();
    if (c == null) throw const SyncException('请先保存账号与应用密码');
    await _cloudSync.restoreBackup(c, name);
    _ref.invalidate(pendingDeletesProvider);
    _onDataChanged();
  }

  Future<void> deleteCloudBackup(String name) async {
    final c = await _savedCloudCredentials();
    if (c == null) throw const SyncException('请先保存账号与应用密码');
    await _cloudSync.deleteBackup(c, name);
  }

  /// 铃铛点击：申请通知权限（拒绝则降级站内红点，不反复弹）→ 置当日已读。
  Future<void> onBellTapped() async {
    final s = _ref.read(settingsProvider);
    if (s.dailySummaryEnabled) {
      await _ref.read(notificationServiceProvider).requestPermission();
    }
    await _settings.markBellRead();
  }
}

/// 最近一次备份信息（状态行展示）。
final lastBackupInfoProvider =
    FutureProvider<({DateTime? at, int? size, bool ok, String error})>(
        (ref) async {
  final s = ref.watch(settingsProvider);
  return (
    at: s.lastBackupAt,
    size: s.lastBackupSize,
    ok: s.lastBackupOk,
    error: s.lastBackupError
  );
});

final inventoryActionsProvider = Provider<InventoryActions>((ref) {
  return InventoryActions(ref);
});
