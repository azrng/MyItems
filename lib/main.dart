import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/inventory_repository.dart';
import 'providers/core_providers.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dirs = await resolveAppDirectories();
  final db = openAppDatabase(dirs.db);

  // 启动期读取设置快照，供首帧（主题/引导路由）同步使用
  final raw = await DriftInventoryRepository(db).getAllSettings();
  final seed = settingsFromMap(raw);

  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      imageDirProvider.overrideWithValue(dirs.images),
      backupDirsProvider.overrideWithValue((
        backup: dirs.backup,
        export: dirs.export,
        cache: dirs.cache,
        db: dirs.db,
      )),
      settingsSeedProvider.overrideWithValue(seed),
    ],
    child: const WarmPantryApp(),
  ));
}
