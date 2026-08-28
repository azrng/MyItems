import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' hide Batch;
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../database/app_database.dart';
import '../repositories/inventory_repository.dart';
import 'image_service.dart';
import 'seed_service.dart';

/// 备份格式常量（requirement.md §7.1，schema v1 全新基线）。
const backupFormatId = 'azrng.warm_pantry.backup';
const backupSchemaVersion = 1;

/// 完整备份 / 恢复（ZIP = backup.json + images/）。
/// 手动导出固定走「私有导出目录 + 系统分享面板」；自动备份写私有备份目录。
/// （Android 10+ 公共 Download 目录需 MediaStore/SAF，与原型假设不同，见交付说明。）
class BackupService {
  final InventoryRepository repo;
  final ImageService images;
  final SeedService seed;
  final Directory backupDir;
  final Directory exportDir;
  final Directory cacheDir;
  final File dbFile;

  BackupService({
    required this.repo,
    required this.images,
    required this.seed,
    required this.backupDir,
    required this.exportDir,
    required this.cacheDir,
    required this.dbFile,
  });

  // ============ 导出 ============

  /// 执行完整备份并校验。[kind] = auto | manual | pre_restore。
  Future<File> exportBackup({required String kind}) async {
    final dir = kind == 'auto' ? backupDir : exportDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final stamp = DateTime.now();
    final prefix = kind == 'pre_restore' ? 'warmpantry_pre_restore' : 'warmpantry_backup';
    final file = File(p.join(
        dir.path, '${prefix}_${_stamp(stamp)}.myitems.zip'));

    await _writeZip(file);
    final ok = await _verifyZip(file);
    if (!ok) {
      if (await file.exists()) await file.delete();
      throw const BackupException('校验未通过，请重新导出');
    }
    await _recordSuccess(file);
    if (kind == 'auto') await _rollOldBackups();
    return file;
  }

  String _stamp(DateTime t) =>
      '${Fmt.date(t).replaceAll('-', '')}-${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}${t.second.toString().padLeft(2, '0')}';

  Future<void> _writeZip(File target) async {
    final json = await _buildBackupJson();
    final encoder = ZipFileEncoder();
    encoder.create(target.path);
    final tmpJson = File(p.join((await target.parent.create(recursive: true)).path,
        '.backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await tmpJson.writeAsString(jsonEncode(json), flush: true);
    encoder.addFile(tmpJson, 'backup.json');
    // 图片按批次 ImagePath 文件名原样打包
    if (await images.imagesDir.exists()) {
      await for (final f in images.imagesDir.list()) {
        if (f is File) encoder.addFile(f, 'images/${p.basename(f.path)}');
      }
    }
    encoder.close();
    if (await tmpJson.exists()) await tmpJson.delete();
  }

  Future<Map<String, dynamic>> _buildBackupJson() async {
    final categories = await repo.getCategories();
    final locations = await repo.getLocations();
    final items = await _allItems();
    final batches = await _allBatches();
    final logs = await repo.getLogs(limit: 1 << 31);
    final repurchases = await _allRepurchases();
    final settings = await repo.getAllSettings();
    return {
      'format': backupFormatId,
      'schemaVersion': backupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories.map(_categoryJson).toList(),
      'locations': locations.map(_locationJson).toList(),
      'items': items.map(_itemJson).toList(),
      'batches': batches.map(_batchJson).toList(),
      'inventoryLogs': logs.map(_logJson).toList(),
      'repurchases': repurchases.map(_repurchaseJson).toList(),
      'settings': settings,
    };
  }

  Future<List<Item>> _allItems() async => repo.watchItems().first;

  Future<List<Batch>> _allBatches() async => repo.watchBatches().first;

  Future<List<RepurchaseItem>> _allRepurchases() async => repo.watchRepurchases().first;

  Map<String, dynamic> _categoryJson(Category c) => {
        'id': c.id, 'name': c.name, 'description': c.description,
        'icon': c.icon, 'colorKey': c.colorKey, 'sortOrder': c.sortOrder,
        'isPreset': c.isPreset,
      };

  Map<String, dynamic> _locationJson(StorageLocation l) => {
        'id': l.id, 'name': l.name, 'region': l.region, 'icon': l.icon,
        'capacity': l.capacity, 'sortOrder': l.sortOrder, 'isActive': l.isActive,
      };

  Map<String, dynamic> _itemJson(Item i) => {
        'id': i.id, 'name': i.name, 'spec': i.spec, 'categoryId': i.categoryId,
        'barcode': i.barcode, 'icon': i.icon, 'isConsumable': i.isConsumable,
        'reminderEnabled': i.reminderEnabled, 'lastLocationId': i.lastLocationId,
        'isArchived': i.isArchived,
        'archivedAt': i.archivedAt?.toIso8601String(),
        'createdAt': i.createdAt.toIso8601String(),
        'updatedAt': i.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> _batchJson(Batch b) => {
        'id': b.id, 'itemId': b.itemId,
        'expiryDate': b.expiryDate?.toIso8601String(),
        'openedAt': b.openedAt?.toIso8601String(),
        'openShelfLifeDays': b.openShelfLifeDays,
        'locationId': b.locationId,
        'initialQuantity': b.initialQuantity,
        'remainingQuantity': b.remainingQuantity,
        'unit': b.unit, 'notes': b.notes,
        'purchasePrice': b.purchasePrice,
        'purchaseDate': b.purchaseDate?.toIso8601String(),
        'imagePath': b.imagePath, 'batchLabel': b.batchLabel,
        'createdAt': b.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _logJson(InventoryLog l) => {
        'id': l.id, 'itemId': l.itemId, 'batchId': l.batchId, 'type': l.type,
        'quantity': l.quantity, 'unit': l.unit, 'locationText': l.locationText,
        'source': l.source, 'note': l.note, 'createdAt': l.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _repurchaseJson(RepurchaseItem r) =>
      {'id': r.id, 'itemId': r.itemId, 'status': r.status, 'createdAt': r.createdAt.toIso8601String()};

  /// 校验：重新解包 backup.json 并校验格式标识与 schema（「校验通过 ✓」的依据）。
  Future<bool> _verifyZip(File zip) async {
    try {
      final json = await _readBackupJson(zip);
      return json != null &&
          json['format'] == backupFormatId &&
          json['schemaVersion'] == backupSchemaVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> _recordSuccess(File file) async {
    final size = await file.length();
    await repo.setSettings({
      SettingKeys.lastBackupAt: DateTime.now().toIso8601String(),
      SettingKeys.lastBackupSize: '$size',
      SettingKeys.lastBackupOk: '1',
      SettingKeys.lastBackupError: '',
    });
  }

  Future<void> _recordFailure(String message) async {
    await repo.setSettings({
      SettingKeys.lastBackupOk: '0',
      SettingKeys.lastBackupError: message,
    });
  }

  /// 失败静默落状态，由界面红色 pill 展示（requirement.md §7.1 失败态）。
  Future<void> exportBackupSafely({required String kind}) async {
    try {
      await exportBackup(kind: kind);
    } on BackupException catch (e) {
      await _recordFailure(e.message);
    } catch (e) {
      await _recordFailure('备份失败：$e');
    }
  }

  /// 自动备份：每日首次启动补做 + 变更后防抖由 Provider 层调度。
  Future<void> autoBackupIfNeeded() async {
    final enabled = await repo.getSetting(SettingKeys.autoBackupEnabled);
    if (enabled == '0') return;
    final last = await repo.getSetting(SettingKeys.lastBackupAt);
    final today = Fmt.date(DateTime.now());
    final lastDay = last == null ? null : Fmt.date(DateTime.tryParse(last) ?? DateTime(0));
    if (lastDay != today) {
      await exportBackupSafely(kind: 'auto');
    }
  }

  Future<void> _rollOldBackups() async {
    final keepCount = int.tryParse(await repo.getSetting(SettingKeys.backupKeepCount) ?? '') ??
        SettingDefaults.backupKeepCount;
    if (!await backupDir.exists()) return;
    final backups = (await backupDir.list().toList())
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('warmpantry_backup_'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (final f in backups.skip(keepCount)) {
      await f.delete();
    }
  }

  // ============ 恢复 ============

  Future<Map<String, dynamic>?> _readBackupJson(File zip) async {
    final decoder = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final entry = decoder.findFile('backup.json');
    if (entry == null) return null;
    return jsonDecode(utf8.decode(entry.content as List<int>)) as Map<String, dynamic>;
  }

  /// 恢复流程（requirement.md §7.1）：预导出 → 解包校验 → 覆盖 → 图片回填 → 补预置。
  Future<void> restoreFromZip(File zip) async {
    final json = await _readBackupJson(zip);
    if (json == null || json['format'] != backupFormatId) {
      throw const BackupException('不是有效的暖仓备份包');
    }
    // 后悔药：覆盖前先导出当前数据
    await exportBackup(kind: 'pre_restore');

    final categories = (json['categories'] as List? ?? []).cast<Map<String, dynamic>>();
    final locations = (json['locations'] as List? ?? []).cast<Map<String, dynamic>>();
    final items = (json['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final batches = (json['batches'] as List? ?? []).cast<Map<String, dynamic>>();
    final logs = (json['inventoryLogs'] as List? ?? []).cast<Map<String, dynamic>>();
    final repurchases = (json['repurchases'] as List? ?? []).cast<Map<String, dynamic>>();
    final settings = (json['settings'] as Map<String, dynamic>? ?? {});

    await repo.replaceAllData(
      categories: categories.map(_categoryFromJson).toList(),
      locations: locations.map(_locationFromJson).toList(),
      items: items.map(_itemFromJson).toList(),
      batches: batches.map(_batchFromJson).toList(),
      logs: logs.map(_logFromJson).toList(),
      repurchases: repurchases.map(_repurchaseFromJson).toList(),
    );
    await repo.setSettings(settings.map((k, v) => MapEntry(k, '$v')));

    // 图片回填：缺失图片的批次按无照片处理，不阻断导入
    await images.ensureDir();
    final decoder = ZipDecoder().decodeBytes(await zip.readAsBytes());
    for (final entry in decoder.files) {
      if (entry.isFile && entry.name.startsWith('images/')) {
        final name = p.basename(entry.name);
        final out = File(p.join(images.imagesDir.path, name));
        if (!await out.exists()) {
          await out.writeAsBytes(entry.content as List<int>);
        }
      }
    }

    // 导入完成后补齐预置分类与位置（同名不动）
    await seed.seed(withPresetLocations: true);
  }

  CategoriesCompanion _categoryFromJson(Map<String, dynamic> j) => CategoriesCompanion(
        id: Value(j['id'] as String),
        name: Value(j['name'] as String),
        description: Value(j['description'] as String?),
        icon: Value(j['icon'] as String?),
        colorKey: Value((j['colorKey'] as String?) ?? 'accent'),
        sortOrder: Value((j['sortOrder'] as num?)?.toInt() ?? 0),
        isPreset: Value((j['isPreset'] as bool?) ?? false),
      );

  StorageLocationsCompanion _locationFromJson(Map<String, dynamic> j) =>
      StorageLocationsCompanion(
        id: Value(j['id'] as String),
        name: Value(j['name'] as String),
        region: Value((j['region'] as String?) ?? '其他区域'),
        icon: Value(j['icon'] as String?),
        capacity: Value((j['capacity'] as num?)?.toInt()),
        sortOrder: Value((j['sortOrder'] as num?)?.toInt() ?? 0),
        isActive: Value((j['isActive'] as bool?) ?? true),
      );

  ItemsCompanion _itemFromJson(Map<String, dynamic> j) => ItemsCompanion(
        id: Value(j['id'] as String),
        name: Value(j['name'] as String),
        spec: Value(j['spec'] as String?),
        categoryId: Value(j['categoryId'] as String),
        barcode: Value(j['barcode'] as String?),
        icon: Value(j['icon'] as String?),
        isConsumable: Value((j['isConsumable'] as bool?) ?? true),
        reminderEnabled: Value((j['reminderEnabled'] as bool?) ?? true),
        lastLocationId: Value(j['lastLocationId'] as String?),
        isArchived: Value((j['isArchived'] as bool?) ?? false),
        archivedAt: Value(_date(j['archivedAt'])),
        createdAt: Value(_date(j['createdAt']) ?? DateTime.now()),
        updatedAt: Value(_date(j['updatedAt']) ?? DateTime.now()),
      );

  BatchesCompanion _batchFromJson(Map<String, dynamic> j) => BatchesCompanion(
        id: Value(j['id'] as String),
        itemId: Value(j['itemId'] as String),
        expiryDate: Value(_date(j['expiryDate'])),
        openedAt: Value(_date(j['openedAt'])),
        openShelfLifeDays: Value((j['openShelfLifeDays'] as num?)?.toInt()),
        locationId: Value(j['locationId'] as String?),
        initialQuantity: Value((j['initialQuantity'] as num?)?.toDouble() ?? 1),
        remainingQuantity: Value((j['remainingQuantity'] as num?)?.toDouble() ?? 1),
        unit: Value((j['unit'] as String?) ?? '件'),
        notes: Value(j['notes'] as String?),
        purchasePrice: Value((j['purchasePrice'] as num?)?.toDouble()),
        purchaseDate: Value(_date(j['purchaseDate'])),
        imagePath: Value(j['imagePath'] as String?),
        batchLabel: Value((j['batchLabel'] as String?) ?? ''),
        createdAt: Value(_date(j['createdAt']) ?? DateTime.now()),
      );

  InventoryLogsCompanion _logFromJson(Map<String, dynamic> j) => InventoryLogsCompanion(
        id: Value(j['id'] as String),
        itemId: Value(j['itemId'] as String),
        batchId: Value(j['batchId'] as String?),
        type: Value((j['type'] as String?) ?? 'adjust'),
        quantity: Value((j['quantity'] as num?)?.toDouble() ?? 0),
        unit: Value((j['unit'] as String?) ?? '件'),
        locationText: Value(j['locationText'] as String?),
        source: Value((j['source'] as String?) ?? ''),
        note: Value(j['note'] as String?),
        createdAt: Value(_date(j['createdAt']) ?? DateTime.now()),
      );

  RepurchaseItemsCompanion _repurchaseFromJson(Map<String, dynamic> j) =>
      RepurchaseItemsCompanion(
        id: Value(j['id'] as String),
        itemId: Value(j['itemId'] as String),
        status: Value((j['status'] as String?) ?? '待购'),
        createdAt: Value(_date(j['createdAt']) ?? DateTime.now()),
      );

  DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v');

  // ============ 存储占用概览（requirement.md §5.11） ============

  Future<({int db, int images, int backups, int cache})> storageUsage() async {
    Future<int> fileWithSidecars(File f) async {
      var total = 0;
      for (final suffix in ['', '-wal', '-shm']) {
        final s = File('${f.path}$suffix');
        if (await s.exists()) total += await s.length();
      }
      return total;
    }

    final dbBytes = await fileWithSidecars(dbFile);
    final imagesBytes = await images.imagesBytes();
    final backupsBytes = await images.dirSize(backupDir);
    final cacheBytes = await images.dirSize(cacheDir);
    return (db: dbBytes, images: imagesBytes, backups: backupsBytes, cache: cacheBytes);
  }

  Future<void> clearCache() async {
    if (!await cacheDir.exists()) return;
    await for (final f in cacheDir.list(recursive: true, followLinks: false)) {
      try {
        if (f is File) await f.delete();
      } catch (_) {
        // 单个缓存文件占用时跳过，不阻断整体清理
      }
    }
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}
