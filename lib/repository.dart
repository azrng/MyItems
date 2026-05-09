import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class ItemRepository {
  ItemRepository({Database? database}) : _database = database;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'my_items_flutter.db');
    _database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _migrateSchema(db);
        await _seedPresetCategories(db);
        await _seedPresetLocations(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createSchema(db);
        await _migrateSchema(db);
        await _seedPresetCategories(db);
        await _seedPresetLocations(db);
      },
      onOpen: (db) async {
        await _createSchema(db);
        await _migrateSchema(db);
        await _seedPresetCategories(db);
        await _seedPresetLocations(db);
      },
    );
    return _database!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<ThemePreference> getThemePreference() async {
    final db = await database;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['theme_preference'],
      limit: 1,
    );
    return rows.isEmpty
        ? ThemePreference.system
        : ThemePreference.fromValue(rows.first['value'] as String?);
  }

  Future<void> saveThemePreference(ThemePreference preference) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'theme_preference', 'value': preference.value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS version_log (
  version INTEGER PRIMARY KEY,
  description TEXT NOT NULL,
  applied_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  description TEXT NOT NULL,
  applied_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT,
  sort_order INTEGER NOT NULL,
  is_preset INTEGER NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category_id TEXT NOT NULL,
  barcode TEXT,
  brand TEXT,
  icon TEXT,
  default_location TEXT,
  is_archived INTEGER NOT NULL DEFAULT 0,
  purchase_date TEXT,
  purchase_price REAL,
  expiry_date TEXT,
  quantity INTEGER NOT NULL DEFAULT 1,
  initial_quantity INTEGER NOT NULL DEFAULT 1,
  remaining_quantity INTEGER NOT NULL DEFAULT 1,
  track_daily_cost INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  image_path TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS locations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS consumption_records (
  id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  type TEXT NOT NULL,
  consumed_at TEXT NOT NULL
)
''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_archived ON items(is_archived)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_expiry ON items(expiry_date)');
  }

  Future<void> _migrateSchema(Database db) async {
    await _addColumnIfMissing(
        db, 'items', 'initial_quantity', 'INTEGER NOT NULL DEFAULT 1');
    await _addColumnIfMissing(
        db, 'items', 'remaining_quantity', 'INTEGER NOT NULL DEFAULT 1');
    await db.execute('''
UPDATE items
SET initial_quantity = quantity
WHERE initial_quantity IS NULL OR initial_quantity < 1
''');
    await db.execute('''
UPDATE items
SET remaining_quantity = quantity
WHERE remaining_quantity IS NULL OR remaining_quantity < 0
''');
    await db.insert(
      'schema_migrations',
      {
        'version': 2,
        'description': 'add_quantity_consumption_locations',
        'applied_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _seedPresetCategories(Database db) async {
    for (final category in presetCategories) {
      await db.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _seedPresetLocations(Database db) async {
    for (final location in presetLocations) {
      await db.insert(
        'locations',
        location.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<List<StorageLocation>> getLocations({bool includeInactive = false}) async {
    final db = await database;
    final rows = await db.query(
      'locations',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(StorageLocation.fromMap).toList();
  }

  Future<void> saveLocation(StorageLocation location) async {
    final db = await database;
    await db.insert('locations', location.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> renameLocation(String locationId, String name) async {
    final db = await database;
    await db.update('locations', {'name': name},
        where: 'id = ?', whereArgs: [locationId]);
  }

  Future<void> deleteLocation(StorageLocation location) async {
    final db = await database;
    await db.update('locations', {'is_active': 0},
        where: 'id = ?', whereArgs: [location.id]);
  }

  Future<List<Category>> getCategories({bool includeInactive = false}) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<void> saveCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> renameCategory(
      Category category, String name, String icon) async {
    final db = await database;
    await db.update(
      'categories',
      {'name': name, 'icon': icon},
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> updateCategoryOrder(List<Category> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final category in categories) {
        await txn.update(
          'categories',
          {'sort_order': category.sortOrder},
          where: 'id = ?',
          whereArgs: [category.id],
        );
      }
    });
  }

  Future<bool> categoryHasItems(String categoryId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(1) AS count FROM items WHERE category_id = ? AND is_archived = 0',
      [categoryId],
    );
    return ((rows.first['count'] as num?) ?? 0).toInt() > 0;
  }

  Future<void> deleteCategory(Category category) async {
    if (category.isPreset) {
      throw RepositoryException('预置分类不可删除');
    }
    if (await categoryHasItems(category.id)) {
      throw RepositoryException('该分类下还有物品，无法删除');
    }
    final db = await database;
    await db.update('categories', {'is_active': 0},
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<List<Item>> getItems({
    ItemQuery query = const ItemQuery(),
    bool includeArchived = false,
  }) async {
    final db = await database;
    final where = <String>[if (!includeArchived) 'is_archived = 0'];
    final args = <Object?>[];
    if (query.categoryId != null) {
      where.add('category_id = ?');
      args.add(query.categoryId);
    }
    if (query.searchText != null && query.searchText!.trim().isNotEmpty) {
      final keyword = '%${query.searchText!.trim()}%';
      where.add(
          '(name LIKE ? OR brand LIKE ? OR default_location LIKE ? OR barcode LIKE ?)');
      args.addAll([keyword, keyword, keyword, keyword]);
    }
    if (query.hasExpiry || query.onlyExpired || query.onlyExpiring) {
      where.add('expiry_date IS NOT NULL');
    }
    final rows = await db.query(
      'items',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: query.onlyExpiring || query.onlyExpired || query.hasExpiry
          ? 10000
          : query.limit,
      offset: query.onlyExpiring || query.onlyExpired || query.hasExpiry
          ? null
          : query.offset,
    );
    return rows.map(Item.fromMap).toList();
  }

  Future<Item?> getItem(String id) async {
    final db = await database;
    final rows =
        await db.query('items', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  Future<String> saveItem(Item item) async {
    final db = await database;
    await db.insert('items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return item.id;
  }

  Future<void> archiveItem(String itemId) async {
    final db = await database;
    await db.update(
      'items',
      {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteItem(String itemId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('consumption_records',
          where: 'item_id = ?', whereArgs: [itemId]);
      await txn.delete('items', where: 'id = ?', whereArgs: [itemId]);
    });
  }

  Future<void> consumeItem(String itemId,
      {required int quantity, required ConsumptionType type}) async {
    if (quantity < 1) return;
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('items',
          where: 'id = ?', whereArgs: [itemId], limit: 1);
      if (rows.isEmpty) {
        throw const RepositoryException('物品不存在');
      }
      final item = Item.fromMap(rows.first);
      final consumed =
          quantity > item.remainingQuantity ? item.remainingQuantity : quantity;
      if (consumed < 1) {
        throw const RepositoryException('该物品已耗尽');
      }
      final remaining = item.remainingQuantity - consumed;
      await txn.update(
        'items',
        {
          'remaining_quantity': remaining,
          'is_archived': remaining == 0 ? 1 : (item.isArchived ? 1 : 0),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );
      await txn.insert(
        'consumption_records',
        ConsumptionRecord(
          id: newId(),
          itemId: itemId,
          quantity: consumed,
          type: type,
          consumedAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  Future<List<ConsumptionRecord>> getConsumptionRecords(String itemId) async {
    final db = await database;
    final rows = await db.query(
      'consumption_records',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'consumed_at DESC',
    );
    return rows.map(ConsumptionRecord.fromMap).toList();
  }

  Future<List<ConsumptionRecord>> getAllConsumptionRecords() async {
    final db = await database;
    final rows = await db.query(
      'consumption_records',
      orderBy: 'consumed_at DESC',
    );
    return rows.map(ConsumptionRecord.fromMap).toList();
  }

  Future<List<ConsumptionRecordDisplay>> getConsumptionRecordDisplays() async {
    final db = await database;
    final rows = await db.rawQuery('''
SELECT
  r.id,
  r.item_id,
  r.quantity,
  r.type,
  r.consumed_at,
  COALESCE(i.name, '已删除物品') AS item_name
FROM consumption_records r
LEFT JOIN items i ON i.id = r.item_id
ORDER BY r.consumed_at DESC
''');
    return rows.map((row) {
      return ConsumptionRecordDisplay(
        record: ConsumptionRecord.fromMap(row),
        itemName: row['item_name'] as String,
      );
    }).toList();
  }

  Future<List<ItemDisplay>> getItemDisplays(
      {ItemQuery query = const ItemQuery()}) async {
    final categories = await getCategories();
    final lookup = {for (final category in categories) category.id: category};
    final items = await getItems(query: query);
    final displays = items
        .map((item) => ItemDisplay.fromItem(
              item: item,
              category: lookup[item.categoryId] ?? fallbackCategory,
            ))
        .where((display) => !query.hasExpiry || display.item.expiryDate != null)
        .where((display) =>
            !query.onlyExpired || display.expiryStatus == ExpiryStatus.expired)
        .where((display) =>
            !query.onlyExpiring ||
            display.expiryStatus == ExpiryStatus.expired ||
            display.expiryStatus == ExpiryStatus.expiring)
        .toList();

    displays.sort((a, b) {
      if (query.onlyExpiring || query.onlyExpired || query.hasExpiry) {
        final status = a.expiryStatus.index.compareTo(b.expiryStatus.index);
        if (status != 0) return status;
        final aExpiry = a.item.expiryDate ?? DateTime(9999);
        final bExpiry = b.item.expiryDate ?? DateTime(9999);
        return aExpiry.compareTo(bExpiry);
      }
      return b.item.createdAt.compareTo(a.item.createdAt);
    });

    return displays.take(query.limit).toList();
  }

  Future<List<ItemDisplay>> getArchivedItemDisplays() async {
    final categories = await getCategories(includeInactive: true);
    final lookup = {for (final category in categories) category.id: category};
    final items = (await getItems(includeArchived: true))
        .where((item) => item.isArchived)
        .toList();
    return items
        .map((item) => ItemDisplay.fromItem(
              item: item,
              category: lookup[item.categoryId] ?? fallbackCategory,
            ))
        .toList();
  }

  Future<List<ItemDisplay>> getHomeItemDisplays(
      {String? searchText, int limit = 1000}) async {
    final categories = await getCategories();
    final lookup = {for (final category in categories) category.id: category};
    final displays =
        (await getItems(query: ItemQuery(searchText: searchText, limit: limit)))
            .map((item) => ItemDisplay.fromItem(
                  item: item,
                  category: lookup[item.categoryId] ?? fallbackCategory,
                ))
            .toList();

    displays.sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));
    return displays.take(limit).toList();
  }

  Future<List<ExpiryGroup>> getExpiryGroups({String? searchText}) async {
    final displays = await getItemDisplays(
      query: ItemQuery(searchText: searchText, onlyExpiring: true, limit: 1000),
    );
    return [ExpiryStatus.expired, ExpiryStatus.expiring]
        .map((status) => ExpiryGroup(
              status: status,
              title: getGroupTitle(status),
              icon: getGroupIcon(status),
              items: displays
                  .where((item) => item.expiryStatus == status)
                  .toList(),
            ))
        .toList();
  }

  Future<LibraryStatistics> getStatistics() async {
    final displays =
        await getItemDisplays(query: const ItemQuery(limit: 10000));
    final valid = displays
        .where((item) => item.expiryStatus != ExpiryStatus.expired)
        .fold<double>(
            0,
            (sum, item) =>
                sum +
                (item.item.purchasePrice ?? 0) * item.item.remainingQuantity);
    final validCount = displays
        .where((item) => item.expiryStatus != ExpiryStatus.expired)
        .length;
    return LibraryStatistics(
      totalSpent: valid,
      totalItems: displays.length,
      validItems: validCount,
    );
  }

  Future<String> exportToCsv() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'my_items_export.csv'));
    final categories = await getCategories();
    final items = await getItems();
    final rows = <List<Object?>>[
      [
        'type',
        'id',
        'name',
        'category_id',
        'icon',
        'barcode',
        'brand',
        'location',
        'unit_price',
        'purchase_date',
        'expiry_date',
        'initial_quantity',
        'remaining_quantity',
        'track_daily_cost',
        'notes',
        'created_at',
        'updated_at',
        'is_archived'
      ],
      ...categories.map((c) => [
            'category',
            c.id,
            c.name,
            '',
            c.icon,
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
          ]),
      ...items.map((i) => [
            'item',
            i.id,
            i.name,
            i.categoryId,
            i.icon,
            i.barcode,
            i.brand,
            i.defaultLocation,
            i.purchasePrice,
            i.purchaseDate?.toIso8601String(),
            i.expiryDate?.toIso8601String(),
            i.initialQuantity,
            i.remainingQuantity,
            i.trackDailyCost ? 1 : 0,
            i.notes,
            i.createdAt.toIso8601String(),
            i.updatedAt.toIso8601String(),
            i.isArchived ? 1 : 0,
          ]),
    ];
    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return file.path;
  }

  Future<String> exportBackup() async {
    final backup = await buildBackupFile();
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, backup.$1));
    await file.writeAsString(backup.$2);
    return file.path;
  }

  Future<(String fileName, String content)> buildBackupFile() async {
    final exportedAt = DateTime.now();
    final timestamp = backupTimestamp(exportedAt);
    final db = await database;
    final settingsRows = await db.query('settings');
    final settings = {
      for (final row in settingsRows)
        row['key'] as String: row['value'] as String,
    };
    final payload = buildBackupPayload(
      categories: await getCategories(includeInactive: true),
      locations: await getLocations(includeInactive: true),
      items: await getItems(includeArchived: true),
      consumptionRecords: await getAllConsumptionRecords(),
      settings: settings,
      exportedAt: exportedAt,
    );
    return (
      'my_items_backup_$timestamp.myitems.json',
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<(int successCount, int failureCount, List<String> errors)> importBackup(
      String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return (0, 1, ['文件不存在：$filePath']);
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return (0, 1, const ['备份文件格式不正确']);
      }
      final backup = parseBackupPayload(decoded);
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('consumption_records');
        await txn.delete('items');
        await txn.delete('locations');
        await txn.delete('categories');
        await txn.delete('settings');

        for (final category in backup.categories) {
          await txn.insert('categories', category.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final location in backup.locations) {
          await txn.insert('locations', location.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final item in backup.items) {
          await txn.insert('items', item.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final record in backup.consumptionRecords) {
          await txn.insert('consumption_records', record.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final entry in backup.settings.entries) {
          await txn.insert(
            'settings',
            {'key': entry.key, 'value': entry.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      await _seedPresetCategories(db);
      await _seedPresetLocations(db);
      final success = backup.categories.length +
          backup.locations.length +
          backup.items.length +
          backup.consumptionRecords.length +
          backup.settings.length;
      return (success, 0, <String>[]);
    } catch (error) {
      return (0, 1, ['导入备份失败：$error']);
    }
  }

  Future<(int successCount, int failureCount, List<String> errors)>
      importFromCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return (0, 1, ['文件不存在：$filePath']);
    }
    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);
    if (rows.length <= 1) return (0, 0, <String>[]);

    var success = 0;
    var failure = 0;
    final errors = <String>[];
    final header = rows.first.map((value) => value?.toString() ?? '').toList();
    final columns = csvColumnIndexes(header);
    for (final row in rows.skip(1)) {
      try {
        if (row.isEmpty) continue;
        final type = csvValue(row, columns, const ['type'], fallbackIndex: 0);
        if (type == 'category') {
          await saveCategory(Category(
            id: csvValue(row, columns, const ['id'], fallbackIndex: 1),
            name: csvValue(row, columns, const ['name'], fallbackIndex: 2),
            icon: emptyStringToNull(
                csvValue(row, columns, const ['icon'], fallbackIndex: 4)),
            sortOrder: 100 + success,
            isPreset: false,
          ));
          success++;
        } else if (type == 'item') {
          await saveItem(itemFromCsvRow(row, header, DateTime.now()));
          success++;
        }
      } catch (error) {
        failure++;
        errors.add(error.toString());
      }
    }
    return (success, failure, errors);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('items');
    await db.delete('consumption_records');
    await db.delete('locations', where: 'is_active = 0');
    await db.delete('categories', where: 'is_preset = 0');
    await _seedPresetCategories(db);
    await _seedPresetLocations(db);
  }
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

String? emptyStringToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String rowAt(List<dynamic> row, int index) {
  if (index >= row.length) return '';
  return row[index]?.toString() ?? '';
}

Map<String, int> csvColumnIndexes(List<String> header) {
  return {
    for (var index = 0; index < header.length; index++)
      header[index].trim(): index
  };
}

String csvValue(
  List<dynamic> row,
  Map<String, int> columns,
  List<String> names, {
  int? fallbackIndex,
}) {
  for (final name in names) {
    final index = columns[name];
    if (index != null) return rowAt(row, index);
  }
  return fallbackIndex == null ? '' : rowAt(row, fallbackIndex);
}

bool csvBool(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

String backupTimestamp(DateTime value) {
  return value
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '-');
}

Item itemFromCsvRow(List<dynamic> row, List<String> header, DateTime now) {
  final columns = csvColumnIndexes(header);
  final initialQuantity = int.tryParse(csvValue(
        row,
        columns,
        const ['initial_quantity', 'quantity'],
        fallbackIndex: 11,
      )) ??
      int.tryParse(rowAt(row, 9)) ??
      1;
  final remainingQuantity = int.tryParse(csvValue(
        row,
        columns,
        const ['remaining_quantity'],
        fallbackIndex: 12,
      )) ??
      initialQuantity;

  return Item(
    id: csvValue(row, columns, const ['id'], fallbackIndex: 1),
    name: csvValue(row, columns, const ['name'], fallbackIndex: 2),
    categoryId:
        csvValue(row, columns, const ['category_id'], fallbackIndex: 3),
    icon: emptyStringToNull(
        csvValue(row, columns, const ['icon'], fallbackIndex: 4)),
    barcode: emptyStringToNull(csvValue(row, columns, const ['barcode'])),
    brand: emptyStringToNull(
        csvValue(row, columns, const ['brand'], fallbackIndex: 5)),
    defaultLocation: emptyStringToNull(
        csvValue(row, columns, const ['location'], fallbackIndex: 6)),
    purchasePrice: double.tryParse(csvValue(
      row,
      columns,
      const ['unit_price', 'price'],
      fallbackIndex: 7,
    )),
    purchaseDate: parseDate(csvValue(row, columns, const ['purchase_date'])),
    expiryDate: parseDate(csvValue(
      row,
      columns,
      const ['expiry_date'],
      fallbackIndex: 8,
    )),
    quantity: initialQuantity,
    initialQuantity: initialQuantity,
    remainingQuantity: remainingQuantity,
    trackDailyCost:
        csvBool(csvValue(row, columns, const ['track_daily_cost'])),
    notes: emptyStringToNull(
        csvValue(row, columns, const ['notes'], fallbackIndex: 10)),
    createdAt: parseDate(csvValue(row, columns, const ['created_at'])) ?? now,
    updatedAt: parseDate(csvValue(row, columns, const ['updated_at'])) ?? now,
    isArchived: csvBool(csvValue(row, columns, const ['is_archived'])),
  );
}

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

const fallbackCategory = Category(
  id: 'other',
  name: '其他',
  icon: '📦',
  sortOrder: 999,
  isPreset: true,
);

const presetCategories = [
  Category(id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
  Category(
      id: 'beauty', name: '化妆品/护肤品', icon: '💄', sortOrder: 2, isPreset: true),
  Category(
      id: 'medicine', name: '药品/保健品', icon: '💊', sortOrder: 3, isPreset: true),
  Category(id: 'daily', name: '日用品', icon: '🧴', sortOrder: 4, isPreset: true),
  Category(
      id: 'electronics',
      name: '电子产品',
      icon: '💻',
      sortOrder: 5,
      isPreset: true),
  fallbackCategory,
];

const presetLocations = [
  StorageLocation(id: 'fridge', name: '冰箱', sortOrder: 1),
  StorageLocation(id: 'freezer', name: '冷冻室', sortOrder: 2),
  StorageLocation(id: 'pantry', name: '储物柜', sortOrder: 3),
  StorageLocation(id: 'medicine_box', name: '药箱', sortOrder: 4),
];
