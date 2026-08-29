import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup_service.dart';
import 'webdav_client.dart';

/// 坚果云数据同步编排（移植自 SmartVault SyncService.cs）：
/// 复用 BackupService 的导出 / 恢复，结合 WebDavClient 上传 / 下载。
/// 凭据由调用方（Actions 层）注入，本服务不持有也不持久化凭据。
class CloudSyncService {
  final BackupService backup;
  final WebDavClient webdav;

  CloudSyncService({required this.backup, required this.webdav});

  /// 测试 WebDAV 连接是否可达、凭据是否正确。
  Future<SyncTestResult> testConnection(WebDavCredentials c) =>
      webdav.testConnection(c);

  /// 导出当前数据为 ZIP 并上传到云端，随后清理超出保留数量的最旧备份。
  Future<CloudBackupEntry> uploadBackup(WebDavCredentials c,
      {required int keepCount}) async {
    final keep = keepCount < 1 ? 1 : keepCount;
    final file = await backup.exportBackup(kind: 'sync', record: false);
    try {
      final bytes = await file.readAsBytes();
      final name = cloudFileName();

      await webdav.ensureDir(c);
      await webdav.put(c, name, bytes);

      // 上传成功后再清理：避免删了旧的、新的又上传失败导致全空
      try {
        final all = await webdav.listBackups(c);
        for (final old in all.skip(keep)) {
          try {
            await webdav.delete(c, old.name);
          } catch (_) {
            // 单个旧备份删除失败不影响整体上传结果
          }
        }
      } catch (_) {
        // 清理阶段失败不影响本次上传成功的事实
      }

      return CloudBackupEntry(
          name: name, exportedAt: DateTime.now(), sizeBytes: bytes.length);
    } finally {
      // 云端已收到字节，本地临时导出即删
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // 清理失败留给缓存一键清理兜底
      }
    }
  }

  /// 列出云端全部历史备份，按时间倒序。
  Future<List<CloudBackupEntry>> listBackups(WebDavCredentials c) =>
      webdav.listBackups(c);

  /// 下载指定云端备份并全量覆盖导入本地（restoreFromZip 内含后悔药预导出，不可自动回滚）。
  Future<void> restoreBackup(WebDavCredentials c, String name) async {
    if (name.trim().isEmpty) {
      throw const SyncException('未选择要恢复的备份');
    }
    final bytes = await webdav.download(c, name);
    await backup.cacheDir.create(recursive: true);
    final tmp = File(p.join(backup.cacheDir.path, 'warmpantry_cloud_restore.zip'));
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await backup.restoreFromZip(tmp);
    } finally {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {
        // 同上，交给缓存清理兜底
      }
    }
  }

  /// 删除云端指定备份。
  Future<void> deleteBackup(WebDavCredentials c, String name) async {
    if (name.trim().isEmpty) {
      throw const SyncException('未选择要删除的备份');
    }
    await webdav.delete(c, name);
  }

  /// 生成带本地时间戳的备份文件名（英文前缀，避免 URL 编码中文）。
  static String cloudFileName([DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'warmpantry-${t.year}${two(t.month)}${two(t.day)}'
        '-${two(t.hour)}${two(t.minute)}${two(t.second)}.zip';
  }
}
