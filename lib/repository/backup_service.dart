import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import 'repository_exception.dart';
import 'schema.dart';

const myItemsBackupFormat = 'azrng.my_items.backup';
const myItemsBackupSchemaVersion = 2;

class MyItemsBackup {
  const MyItemsBackup({
    required this.categories,
    required this.locations,
    required this.items,
    required this.consumptionRecords,
    required this.settings,
  });

  final List<Category> categories;
  final List<StorageLocation> locations;
  final List<Item> items;
  final List<ConsumptionRecord> consumptionRecords;
  final Map<String, String> settings;
}

Map<String, Object?> buildBackupPayload({
  required List<Category> categories,
  required List<StorageLocation> locations,
  required List<Item> items,
  required List<ConsumptionRecord> consumptionRecords,
  required Map<String, String> settings,
  required DateTime exportedAt,
}) {
  return {
    'format': myItemsBackupFormat,
    'schemaVersion': myItemsBackupSchemaVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'app': {
      'name': '我的物品',
      'platform': 'flutter_android',
    },
    'categories': categories.map((category) => category.toMap()).toList(),
    'locations': locations.map((location) => location.toMap()).toList(),
    'items': items.map((item) => item.toMap()).toList(),
    'consumptionRecords':
        consumptionRecords.map((record) => record.toMap()).toList(),
    'settings': settings,
  };
}

MyItemsBackup parseBackupPayload(Map<String, Object?> payload) {
  if (payload['format'] != myItemsBackupFormat) {
    throw const RepositoryException('不是有效的我的物品备份文件');
  }
  final schemaVersion = (payload['schemaVersion'] as num?)?.toInt();
  if (schemaVersion == null || schemaVersion > myItemsBackupSchemaVersion) {
    throw RepositoryException('备份版本不受支持：$schemaVersion');
  }
  return MyItemsBackup(
    categories: mapList(payload['categories']).map(Category.fromMap).toList(),
    locations:
        mapList(payload['locations']).map(StorageLocation.fromMap).toList(),
    items: mapList(payload['items']).map(Item.fromMap).toList(),
    consumptionRecords: mapList(payload['consumptionRecords'])
        .map(ConsumptionRecord.fromMap)
        .toList(),
    settings: stringMap(payload['settings']),
  );
}

List<Map<String, Object?>> mapList(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const RepositoryException('备份数据列表格式不正确');
  }
  return value.map((entry) {
    if (entry is! Map) {
      throw const RepositoryException('备份数据项格式不正确');
    }
    return entry.map((key, value) => MapEntry(key.toString(), value));
  }).toList();
}

Map<String, String> stringMap(Object? value) {
  if (value == null) return const {};
  if (value is! Map) {
    throw const RepositoryException('备份设置格式不正确');
  }
  return value.map((key, value) => MapEntry(key.toString(), value.toString()));
}

String backupTimestamp(DateTime value) {
  return value
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '-');
}

Future<String> writeBackupToFile(String fileName, String content) async {
  final docs = await getApplicationDocumentsDirectory();
  final file = File(p.join(docs.path, fileName));
  await file.writeAsString(content);
  return file.path;
}

String buildBackupFileName(DateTime exportedAt) =>
    'my_items_backup_${backupTimestamp(exportedAt)}.myitems.json';
