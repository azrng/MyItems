import 'package:drift/drift.dart' hide Batch;

import '../../core/constants/app_constants.dart';
import '../../core/utils/expiry_helper.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../database/app_database.dart';
import '../repositories/inventory_repository.dart';

/// 库存业务编排（requirement.md §4 业务规则）。
/// 数据变更一律经由本服务，保证流水、余量、归档状态一致。
class InventoryService {
  final InventoryRepository repo;
  InventoryService(this.repo);

  // ================= 录入 / 再入库（§4.6） =================

  /// 同名物品检查：返回同名未归档物品，由界面弹层决定「挂新批次」还是「新物品」。
  Future<List<Item>> findSameName(String name) =>
      repo.findByName(name.trim()).then(
          (list) => list.where((e) => !e.isArchived).toList());

  /// 入库： newItem 为空表示挂到 existingItemId 名下新建批次。
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
    String? imagePath,
  }) async {
    final now = DateTime.now();
    final String itemId;
    if (existingItemId != null) {
      itemId = existingItemId;
      await repo.updateItem(ItemsCompanion(
        id: Value(itemId),
        updatedAt: Value(now),
        lastLocationId: Value(locationId),
      ));
    } else {
      itemId = newId();
      await repo.insertItem(ItemsCompanion.insert(
        id: itemId,
        name: name.trim(),
        categoryId: categoryId,
        spec: Value(spec?.trim()),
        icon: Value(icon),
        isConsumable: Value(isConsumable),
        reminderEnabled: Value(reminderEnabled),
        lastLocationId: Value(locationId),
        createdAt: now,
        updatedAt: now,
      ));
    }

    final batchId = newId();
    final location = await repo.getLocation(locationId);
    await repo.insertBatch(BatchesCompanion.insert(
      id: batchId,
      itemId: itemId,
      initialQuantity: Value(quantity),
      remainingQuantity: Value(quantity),
      unit: Value(unit),
      locationId: Value(locationId),
      expiryDate: Value(expiryDate),
      notes: Value(notes?.trim()),
      purchasePrice: Value(purchasePrice),
      purchaseDate: Value(purchaseDate),
      imagePath: Value(imagePath),
      batchLabel: Fmt.date(now).replaceAll('-', ''),
      createdAt: now,
    ));

    await repo.insertLogs([
      InventoryLogsCompanion.insert(
        id: newId(),
        itemId: itemId,
        batchId: Value(batchId),
        type: LogTypes.intake,
        quantity: quantity,
        unit: unit,
        locationText: Value(location == null ? null : '来自 ${location.name}'),
        source: existingItemId == null ? LogSources.manual : LogSources.quickIntake,
        note: const Value(null),
        createdAt: now,
      ),
    ]);
    await repo.setSetting(SettingKeys.lastUsedUnit, unit);

    final item = await repo.getItem(itemId);
    return Success(item!);
  }

  // ================= 消耗（§4.3 消耗落点 = FIFO 批次） =================

  /// 物品在库批次按有效到期日升序（FIFO 扣减顺序）。
  Future<List<Batch>> activeBatchesFifo(String itemId, DateTime now) async {
    final batches = await repo.getBatchesOfItems([itemId]);
    return sortFifo(batches, now);
  }

  static List<Batch> sortFifo(List<Batch> batches, DateTime now) {
    double key(Batch b) {
      final e = ExpiryHelper.effectiveExpiry(
          expiryDate: b.expiryDate, openedAt: b.openedAt, openShelfLifeDays: b.openShelfLifeDays);
      return e?.millisecondsSinceEpoch.toDouble() ?? double.maxFinite;
    }

    final list = batches.where((b) => b.remainingQuantity > 0).toList()
      ..sort((a, b) => key(a).compareTo(key(b)));
    return list;
  }

  /// 对物品 FIFO 扣减 qty（跨批次），写入 consume 流水，返回本次扣减明细。
  Future<Result<List<BatchDeduction>>> consumeFifo({
    required String itemId,
    required double quantity,
    required String source,
    String? note,
  }) async {
    if (quantity <= 0) return const Failure('扣减数量必须大于 0');
    final now = DateTime.now();
    final fifo = await activeBatchesFifo(itemId, now);
    final inStock = fifo.fold<double>(0, (s, b) => s + b.remainingQuantity);
    final capped = quantity > inStock ? inStock : quantity;
    if (capped <= 0) return const Failure('没有可消耗的在库余量');

    // FIFO 分配
    var rest = capped;
    final deductions = <BatchDeduction>[];
    for (final b in fifo) {
      if (rest <= 0) break;
      final take = rest >= b.remainingQuantity ? b.remainingQuantity : rest;
      deductions.add(BatchDeduction(b, take));
      rest -= take;
    }
    await repo.applyDeductions(deductions);
    final first = fifo.first;
    await repo.insertLogs([
      InventoryLogsCompanion.insert(
        id: newId(),
        itemId: itemId,
        batchId: Value(deductions.first.batch.id),
        type: LogTypes.consume,
        quantity: capped,
        unit: first.unit,
        locationText: const Value(null),
        source: source,
        note: Value(note ?? _multiBatchNote(deductions, first.unit)),
        createdAt: now,
      ),
    ]);
    return Success(deductions);
  }

  static String? _multiBatchNote(List<BatchDeduction> ds, String unit) {
    if (ds.length <= 1) return null;
    return '跨 ${ds.length} 个批次扣减（FIFO），共 ${Fmt.quantity(ds.fold<double>(0, (s, d) => s + d.amount))} $unit';
  }

  /// 撤销最近一笔消耗（§3.5：物理删除流水并还原批次余量，仅 5 秒窗口内可用）。
  Future<Result<void>> undoConsume(String logId) async {
    final logs = await repo.getLogs(limit: 500);
    final log = logs.where((l) => l.id == logId).firstOrNull;
    if (log == null || log.type != LogTypes.consume) return const Failure('该流水不可撤销');
    if (log.batchId != null) {
      final batch = await repo.getBatch(log.batchId!);
      if (batch != null) {
        await repo.updateBatch(BatchesCompanion(
          id: Value(batch.id),
          remainingQuantity: Value(batch.remainingQuantity + log.quantity),
        ));
      }
    }
    await repo.deleteLog(logId);
    return const Success(null);
  }

  // ================= 用完归档（§4.3 / §4.4） =================

  /// 「✓ 用完」确认后：余量清零 + archive 流水 + 物品归档。返回告别语陪伴天数。
  Future<Result<int>> finishAndArchive({required String itemId}) async {
    final now = DateTime.now();
    final item = await repo.getItem(itemId);
    if (item == null) return const Failure('物品不存在');
    final batches = await repo.getBatchesOfItems([itemId]);
    final active = batches.where((b) => b.remainingQuantity > 0).toList();
    if (active.isNotEmpty) {
      await repo.applyDeductions(
          active.map((b) => BatchDeduction(b, b.remainingQuantity)).toList());
    }
    final firstUnit = batches.isEmpty ? '件' : batches.first.unit;
    final location = item.lastLocationId == null
        ? null
        : await repo.getLocation(item.lastLocationId!);
    await repo.insertLogs([
      InventoryLogsCompanion.insert(
        id: newId(),
        itemId: itemId,
        batchId: const Value(null),
        type: LogTypes.archive,
        quantity: 0,
        unit: firstUnit,
        locationText: Value(location == null ? null : '来自 ${location.name}'),
        source: LogSources.manual,
        note: const Value(null),
        createdAt: now,
      ),
    ]);
    await repo.markArchived(itemId, true, at: now);
    final days = now.difference(item.createdAt).inDays;
    return Success(days < 0 ? 0 : days);
  }

  /// 「不要了，标记用完并入归档」（过期处置引导，§5.13）。
  Future<Result<int>> discardAndArchive({required String itemId}) =>
      finishAndArchive(itemId: itemId);

  // ================= 开封追踪（§4.2） =================

  Future<Result<void>> openBatch({
    required String batchId,
    required DateTime openedAt,
    required int? shelfLifeDays,
  }) async {
    final batch = await repo.getBatch(batchId);
    if (batch == null) return const Failure('批次不存在');
    await repo.updateBatch(BatchesCompanion(
      id: Value(batchId),
      openedAt: Value(openedAt),
      openShelfLifeDays: Value(shelfLifeDays),
    ));
    await _writeAdjustLog(batch, '开封', openedAt: openedAt);
    return const Success(null);
  }

  /// 取消开封：清空开封字段并留痕。
  Future<Result<void>> cancelOpen(String batchId) async {
    final batch = await repo.getBatch(batchId);
    if (batch == null) return const Failure('批次不存在');
    await repo.updateBatch(BatchesCompanion(
      id: Value(batchId),
      openedAt: const Value(null),
      openShelfLifeDays: const Value(null),
    ));
    await _writeAdjustLog(batch, '取消开封');
    return const Success(null);
  }

  /// 修改开封日期 / 限期天数：记录旧值保证可追溯。
  Future<Result<void>> updateOpenInfo({
    required String batchId,
    required DateTime openedAt,
    required int? shelfLifeDays,
  }) async {
    final batch = await repo.getBatch(batchId);
    if (batch == null) return const Failure('批次不存在');
    await repo.updateBatch(BatchesCompanion(
      id: Value(batchId),
      openedAt: Value(openedAt),
      openShelfLifeDays: Value(shelfLifeDays),
    ));
    await _writeAdjustLog(batch, '调整开封信息（原：${batch.openedAt == null ? '未开封' : Fmt.date(batch.openedAt!)}'
        '${batch.openShelfLifeDays == null ? '' : ' / ${batch.openShelfLifeDays} 天'}）');
    return const Success(null);
  }

  // ================= 余量校正 / 移位（§4.3 / §5.13） =================

  Future<Result<void>> adjustRemaining({
    required String batchId,
    required double newValue,
    String? reason,
  }) async {
    final batch = await repo.getBatch(batchId);
    if (batch == null) return const Failure('批次不存在');
    if (newValue < 0) return const Failure('余量不能为负');
    await repo.updateBatch(BatchesCompanion(
      id: Value(batchId),
      remainingQuantity: Value(newValue),
    ));
    await repo.insertLogs([
      InventoryLogsCompanion.insert(
        id: newId(),
        itemId: batch.itemId,
        batchId: Value(batchId),
        type: LogTypes.adjust,
        quantity: newValue,
        unit: batch.unit,
        locationText: const Value(null),
        source: LogSources.adjust,
        note: Value('校正：${Fmt.quantity(batch.remainingQuantity)} → ${Fmt.quantity(newValue)}'
            '${reason == null || reason.isEmpty ? '' : '（$reason）'}'),
        createdAt: DateTime.now(),
      ),
    ]);
    return const Success(null);
  }

  Future<Result<void>> moveBatch({
    required String batchId,
    required String? locationId,
  }) async {
    final batch = await repo.getBatch(batchId);
    if (batch == null) return const Failure('批次不存在');
    String? locationText;
    if (locationId != null) {
      final loc = await repo.getLocation(locationId);
      locationText = '移位至 ${loc?.name ?? '未知位置'}';
    }
    await repo.updateBatch(BatchesCompanion(
      id: Value(batchId),
      locationId: Value(locationId),
    ));
    if (locationId != null) {
      await _writeAdjustLog(batch, locationText!);
    }
    return const Success(null);
  }

  Future<void> _writeAdjustLog(Batch batch, String note, {DateTime? openedAt}) {
    return repo.insertLogs([
      InventoryLogsCompanion.insert(
        id: newId(),
        itemId: batch.itemId,
        batchId: Value(batch.id),
        type: LogTypes.adjust,
        quantity: batch.remainingQuantity,
        unit: batch.unit,
        locationText: const Value(null),
        source: LogSources.adjust,
        note: Value(note),
        createdAt: openedAt ?? DateTime.now(),
      ),
    ]);
  }

  // ================= 删除（§4.8 两段式软删缓冲） =================

  /// 确认删除：先进入待删集合（持久化），界面立即移除；超时/退出后 purge。
  Future<List<String>> softDeleteItems(List<String> itemIds) async {
    final pending = await pendingDeleteIds();
    final next = {...pending, ...itemIds}.toList();
    await repo.setSetting(SettingKeys.pendingDeletes, next.join(','));
    return next;
  }

  Future<List<String>> pendingDeleteIds() async {
    final raw = await repo.getSetting(SettingKeys.pendingDeletes);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }

  /// 撤销软删。
  Future<void> undoSoftDelete(List<String> itemIds) async {
    final pending = await pendingDeleteIds();
    final next = pending.where((e) => !itemIds.contains(e)).toList();
    await repo.setSetting(SettingKeys.pendingDeletes, next.join(','));
  }

  /// 真正落盘清除（窗口超时 / 离开页面 / 冷启动清扫时调用）。返回被清除物品的图片名。
  Future<List<String>> purgePendingDeletes() async {
    final ids = await pendingDeleteIds();
    if (ids.isEmpty) return [];
    final batches = await repo.getBatchesOfItems(ids);
    final images = batches.map((b) => b.imagePath).whereType<String>().toList();
    await repo.deleteItemsAndBatches(ids);
    await repo.setSetting(SettingKeys.pendingDeletes, '');
    return images;
  }

  // ================= 编辑保存（§4.7） =================

  /// 编辑物品：更新主档字段与主批次描述字段；余量变化请走校正（避免账实不符）。
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
    String? imagePath,
  }) async {
    final item = await repo.getItem(itemId);
    if (item == null) return const Failure('物品不存在');
    await repo.updateItem(ItemsCompanion(
      id: Value(itemId),
      name: Value(name.trim()),
      spec: Value(spec?.trim()),
      categoryId: Value(categoryId),
      icon: Value(icon),
      isConsumable: Value(isConsumable),
      reminderEnabled: Value(reminderEnabled),
      updatedAt: Value(DateTime.now()),
    ));
    await repo.updateBatch(BatchesCompanion(
      id: Value(batchId),
      expiryDate: Value(expiryDate),
      locationId: locationId == null ? const Value(null) : Value(locationId),
      notes: Value(notes?.trim()),
      purchasePrice: Value(purchasePrice),
      purchaseDate: Value(purchaseDate),
    ));
    if (imagePath != null) {
      await repo.setImagePath(batchId, imagePath);
    }
    return const Success(null);
  }

  // ================= 批量调整（§4.8） =================

  /// 批量改分类（本身可逆，不设撤销）。
  Future<void> changeCategory(String itemId, String categoryId) {
    return repo.updateItem(ItemsCompanion(
      id: Value(itemId),
      categoryId: Value(categoryId),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 整物移位：对该物品全部在库批次改位置并留痕。
  Future<void> moveAllBatches(String itemId, String locationId) async {
    final batches = await activeBatchesFifo(itemId, DateTime.now());
    for (final b in batches) {
      await moveBatch(batchId: b.id, locationId: locationId);
    }
    await repo.updateItem(ItemsCompanion(
      id: Value(itemId),
      lastLocationId: Value(locationId),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // ================= 回购（§4.4） =================

  Future<void> addToRepurchase(String itemId) {
    return repo.upsertRepurchase(RepurchaseItemsCompanion.insert(
      id: newId(),
      itemId: itemId,
      status: const Value('待购'),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> toggleRepurchaseStatus(RepurchaseItem r) {
    return repo.upsertRepurchase(RepurchaseItemsCompanion(
      id: Value(r.id),
      itemId: Value(r.itemId),
      status: Value(r.status == '待购' ? '已在购物车' : '待购'),
      createdAt: Value(r.createdAt),
    ));
  }

  Future<void> removeRepurchase(String id) => repo.deleteRepurchase(id);

  // ================= 纯统计（§4.11 口径） =================

  /// 连续记录天数：任意流水即活跃，从最后活跃日回数，中断清零。
  static int streakDays(List<InventoryLog> logs, DateTime now) {
    if (logs.isEmpty) return 0;
    final days = logs
        .map((l) => DateTime(l.createdAt.year, l.createdAt.month, l.createdAt.day))
        .toSet();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 近 7 天每日消耗件数（周一 → 周日顺序由界面按需取）。
  static List<int> weeklyConsume(List<InventoryLog> logs, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return logs
          .where((l) =>
              l.type == LogTypes.consume &&
              DateTime(l.createdAt.year, l.createdAt.month, l.createdAt.day) == day)
          .length;
    });
  }

  static int todayConsumeCount(List<InventoryLog> logs, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return logs
        .where((l) =>
            l.type == LogTypes.consume &&
            DateTime(l.createdAt.year, l.createdAt.month, l.createdAt.day) == today)
        .length;
  }
}
