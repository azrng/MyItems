import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/inventory_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/image_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/seed_service.dart';

/// 应用级依赖注入（backend-AGENTS.md：Provider 声明式注册，应用生命周期内保持）。

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('main() 启动时以 override 注入');
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return DriftInventoryRepository(ref.watch(appDatabaseProvider));
});

final imageDirProvider = Provider<Directory>((ref) {
  throw UnimplementedError('main() 启动时以 override 注入');
});

final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService(ref.watch(imageDirProvider));
});

final seedServiceProvider = Provider<SeedService>((ref) {
  return SeedService(ref.watch(inventoryRepositoryProvider));
});

final backupDirsProvider = Provider<({Directory backup, Directory export, Directory cache, File db})>((ref) {
  throw UnimplementedError('main() 启动时以 override 注入');
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final dirs = ref.watch(backupDirsProvider);
  return BackupService(
    repo: ref.watch(inventoryRepositoryProvider),
    images: ref.watch(imageServiceProvider),
    seed: ref.watch(seedServiceProvider),
    backupDir: dirs.backup,
    exportDir: dirs.export,
    cacheDir: dirs.cache,
    dbFile: dirs.db,
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// 启动期一次性目录装配（main() 调用）。
Future<({Directory support, Directory images, Directory backup, Directory export, Directory cache, File db})>
    resolveAppDirectories() async {
  final support = await getApplicationSupportDirectory();
  final images = Directory('${support.path}${Platform.pathSeparator}images');
  final backup = Directory('${support.path}${Platform.pathSeparator}backups');
  final export = Directory('${support.path}${Platform.pathSeparator}exports');
  final cache = await getTemporaryDirectory();
  final db = File('${support.path}${Platform.pathSeparator}warmpantry.sqlite');
  return (
    support: support,
    images: images,
    backup: backup,
    export: export,
    cache: cache,
    db: db,
  );
}
