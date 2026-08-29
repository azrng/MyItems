import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:warmpantry/core/constants/app_constants.dart';
import 'package:warmpantry/data/database/app_database.dart';
import 'package:warmpantry/data/repositories/inventory_repository.dart';
import 'package:warmpantry/core/utils/result.dart';
import 'package:warmpantry/data/services/backup_service.dart';
import 'package:warmpantry/data/services/image_service.dart';
import 'package:warmpantry/data/services/inventory_service.dart';
import 'package:warmpantry/data/services/seed_service.dart';

/// 真实链路 smoke：drift 建库 → 预置种子 → 入库/消耗/归档 → ZIP 备份 →
/// 清库恢复 → 数据一致（backend-AGENTS.md「至少补一项真实链路或等价验证」）。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late DriftInventoryRepository repo;
  late InventoryService svc;
  late BackupService backup;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('warmpantry_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'test.sqlite'))));
    repo = DriftInventoryRepository(db);
    svc = InventoryService(repo);
    final images = ImageService(Directory(p.join(tmp.path, 'images')));
    backup = BackupService(
      repo: repo,
      images: images,
      seed: SeedService(repo),
      backupDir: Directory(p.join(tmp.path, 'backups')),
      exportDir: Directory(p.join(tmp.path, 'exports')),
      cacheDir: Directory(p.join(tmp.path, 'cache')),
      dbFile: File(p.join(tmp.path, 'test.sqlite')),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('备份往返：导出→清空→恢复→数据一致', () async {
    // 1. 种子 + 一笔业务数据
    await SeedService(repo).seed(withPresetLocations: true);
    final cats = await repo.getCategories();
    final locs = await repo.getLocations();
    expect(cats.length, 8, reason: '预置 8 分类');
    expect(locs.length, 8, reason: '预置 8 位置');

    final saved = await svc.saveIntake(
      name: '全麦吐司',
      categoryId: cats.first.id,
      isConsumable: true,
      reminderEnabled: true,
      locationId: locs.first.id,
      quantity: 2,
      unit: '袋',
      expiryDate: DateTime(2026, 9, 5),
    );
    expect(saved, isA<Success<Item>>());
    final item = (saved as Success<Item>).data;

    // 2. 消耗 1 → 用完归档
    final consume = await svc.consumeFifo(
        itemId: item.id, quantity: 1, source: LogSources.quickConsume);
    expect(
        consume,
        isA<Success<({String logId, List<BatchDeduction> deductions})>>());
    final finish = await svc.finishAndArchive(itemId: item.id);
    expect(finish, isA<Success<int>>());

    // 3. 导出 ZIP
    final zip = await backup.exportBackup(kind: 'manual');
    expect(await zip.exists(), isTrue);
    expect(zip.path, endsWith('.myitems.zip'));

    // 4. 清库（模拟新手机）
    await repo.replaceAllData(
      categories: [],
      locations: [],
      items: [],
      batches: [],
      logs: [],
      repurchases: [],
    );
    expect(await repo.getCategories(), isEmpty);

    // 5. 恢复 → 数据一致
    await backup.restoreFromZip(zip);
    final restoredItems = await repo.watchItems().first;
    final restoredLogs = await repo.getLogs();
    expect(restoredItems.length, 1);
    expect(restoredItems.first.name, '全麦吐司');
    expect(restoredItems.first.isArchived, isTrue);
    // intake + consume + archive 三条流水
    expect(restoredLogs.map((l) => l.type).toSet(),
        {LogTypes.intake, LogTypes.consume, LogTypes.archive});
    // 恢复后补齐预置
    expect((await repo.getCategories()).length, 8);
  });

  test('自动备份滚动淘汰：仅保留 N 份', () async {
    for (var i = 0; i < 3; i++) {
      await backup.exportBackup(kind: 'auto');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    await repo.setSetting(SettingKeys.backupKeepCount, '2');
    await backup.exportBackup(kind: 'auto');
    final files = (await backup.backupDir.list().toList())
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('warmpantry_backup_'))
        .toList();
    expect(files.length, 2, reason: '保留版本数=2');
  });
}
