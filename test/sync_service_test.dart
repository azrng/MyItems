import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:warmpantry/core/constants/app_constants.dart';
import 'package:warmpantry/data/database/app_database.dart';
import 'package:warmpantry/data/repositories/inventory_repository.dart';
import 'package:warmpantry/data/services/backup_service.dart';
import 'package:warmpantry/data/services/image_service.dart';
import 'package:warmpantry/data/services/inventory_service.dart';
import 'package:warmpantry/data/services/seed_service.dart';
import 'package:warmpantry/data/services/sync_service.dart';
import 'package:warmpantry/data/services/webdav_client.dart';

/// 坚果云同步编排 smoke：真实 BackupService + 内存 Fake WebDAV，
/// 覆盖推送（含按保留数清理）、云端恢复全链路、sync 导出不记本地备份状态。
void main() {
  late Directory tmp;
  late AppDatabase db;
  late DriftInventoryRepository repo;
  late InventoryService svc;
  late BackupService backup;
  late _FakeDav dav;
  late CloudSyncService sync;
  const creds = WebDavCredentials(
      url: 'https://dav.jianguoyun.com/dav/', user: 'a@b.c', token: 'app-pass');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('warmpantry_sync_test');
    db = AppDatabase(NativeDatabase(File(p.join(tmp.path, 'test.sqlite'))));
    repo = DriftInventoryRepository(db);
    svc = InventoryService(repo);
    backup = BackupService(
      repo: repo,
      images: ImageService(Directory(p.join(tmp.path, 'images'))),
      seed: SeedService(repo),
      backupDir: Directory(p.join(tmp.path, 'backups')),
      exportDir: Directory(p.join(tmp.path, 'exports')),
      cacheDir: Directory(p.join(tmp.path, 'cache')),
      dbFile: File(p.join(tmp.path, 'test.sqlite')),
    );
    dav = _FakeDav();
    sync = CloudSyncService(backup: backup, webdav: dav);
    await SeedService(repo).seed(withPresetLocations: true);
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<int> itemCount() =>
      repo.watchItems().first.then((l) => l.length);

  test('推送：上传到云端、本地临时文件清理、不记本地备份状态', () async {
    await sync.uploadBackup(creds, keepCount: 5);
    expect(dav.stored.length, 1);
    final name = dav.stored.keys.single;
    expect(name.startsWith('warmpantry-'), isTrue);
    expect(name.endsWith('.zip'), isTrue);
    expect(dav.dirEnsured, 1, reason: '上传前先建云端目录');
    // 本地 sync 临时导出已清理
    expect(await backup.cacheDir.exists(), isTrue);
    expect(
        (await backup.cacheDir.list().toList())
            .whereType<File>()
            .where((f) => f.path.contains('warmpantry_sync')),
        isEmpty);
    // sync 导出不写本地备份状态键（云端另有 cloud_sync_* 状态）
    expect(await repo.getSetting(SettingKeys.lastBackupAt), isNull);
  });

  test('推送后按保留数清理最旧云端备份', () async {
    dav.listOverride = [
      CloudBackupEntry(
          name: 'warmpantry-old2.zip',
          exportedAt: DateTime(2026, 8, 27)),
      CloudBackupEntry(
          name: 'warmpantry-old1.zip',
          exportedAt: DateTime(2026, 8, 28)),
      CloudBackupEntry(
          name: 'warmpantry-new.zip', exportedAt: DateTime(2026, 8, 29)),
    ];
    await sync.uploadBackup(creds, keepCount: 2);
    expect(dav.deleted, ['warmpantry-old2.zip'],
        reason: '仅清理超出保留数的最旧一份');
  });

  test('云端恢复：下载 → 覆盖导入 → 数据回到推送时点', () async {
    // 推送时 8 个预置分类物品为 0；推送后录一件，再从云端恢复应回到 0
    final entry = await sync.uploadBackup(creds, keepCount: 5);
    final cats = await repo.getCategories();
    final locs = await repo.getLocations();
    await svc.saveIntake(
      name: '全麦吐司',
      categoryId: cats.first.id,
      isConsumable: true,
      reminderEnabled: true,
      locationId: locs.first.id,
      quantity: 1,
      unit: '件',
    );
    expect(await itemCount(), 1);

    await sync.restoreBackup(creds, entry.name);
    expect(await itemCount(), 0, reason: '云端备份恢复后回到推送时点');
  });

  test('恢复与删除的空名校验', () async {
    expect(() => sync.restoreBackup(creds, ' '),
        throwsA(isA<SyncException>()));
    expect(() => sync.deleteBackup(creds, ''),
        throwsA(isA<SyncException>()));
  });

  test('删除云端指定备份', () async {
    final entry = await sync.uploadBackup(creds, keepCount: 5);
    await sync.deleteBackup(creds, entry.name);
    expect(dav.stored, isEmpty);
  });
}

/// 内存版 WebDAV：不触网，仅实现同步编排用到的五个协议动作。
class _FakeDav extends WebDavClient {
  final stored = <String, List<int>>{};
  final deleted = <String>[];
  int dirEnsured = 0;
  List<CloudBackupEntry>? listOverride;

  @override
  Future<void> ensureDir(WebDavCredentials c) async => dirEnsured++;

  @override
  Future<void> put(WebDavCredentials c, String name, List<int> content) async {
    stored[name] = content;
  }

  @override
  Future<List<CloudBackupEntry>> listBackups(WebDavCredentials c) async {
    final list = listOverride ??
        [
          for (final e in stored.entries)
            CloudBackupEntry(
                name: e.key, sizeBytes: e.value.length,
                exportedAt: DateTime.now()),
        ]..sort((a, b) => b.exportedAt!.compareTo(a.exportedAt!));
    return list;
  }

  @override
  Future<List<int>> download(WebDavCredentials c, String name) async {
    final bytes = stored[name];
    if (bytes == null) throw const SyncException('云端备份不存在或已被删除');
    return bytes;
  }

  @override
  Future<void> delete(WebDavCredentials c, String name) async {
    deleted.add(name);
    stored.remove(name);
  }
}
