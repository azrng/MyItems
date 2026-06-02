import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';
import 'backup_service.dart';
import 'csv_service.dart';
import 'item_repository.dart';
import 'repository_exception.dart';
import 'schema.dart';

class SqliteItemRepository extends ItemRepository {
  SqliteItemRepository({Database? database}) : _database = database;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'my_items_flutter.db');
    _database = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await createSchema(db);
        await runPendingMigrations(db);
        await seedPresetCategories(db);
        await seedPresetLocations(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await createSchema(db);
        await runPendingMigrations(db, fromVersion: oldVersion);
        await seedPresetCategories(db);
        await seedPresetLocations(db);
      },
    );
    return _database!;
  }

  @override
  Future<void> initialize() async {
    await database;
  }

  @override
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

  @override
  Future<void> saveThemePreference(ThemePreference preference) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': 'theme_preference', 'value': preference.value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<StorageLocation>> getLocations({bool includeInactive = false}) async {
    final db = await database;
    final rows = await db.query(
      'locations',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(StorageLocation.fromMap).toList();
  }

  @override
  Future<void> saveLocation(StorageLocation location) async {
    final db = await database;
    await db.insert('locations', location.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> renameLocation(String locationId, String name) async {
    final db = await database;
    await db.update('locations', {'name': name},
        where: 'id = ?', whereArgs: [locationId]);
  }

  @override
  Future<void> deleteLocation(StorageLocation location) async {
    final db = await database;
    await db.update('locations', {'is_active': 0},
        where: 'id = ?', whereArgs: [location.id]);
  }

  @override
  Future<List<Category>> getCategories({bool includeInactive = false}) async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<void> saveCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
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

  @override
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

  @override
  Future<bool> categoryHasItems(String categoryId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(1) AS count FROM items WHERE category_id = ? AND is_archived = 0',
      [categoryId],
    );
    return ((rows.first['count'] as num?) ?? 0).toInt() > 0;
  }

  @override
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

  @override
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
    if (query.onlyExpired) {
      where.add("date(expiry_date) < date('now')");
    }
    if (query.onlyExpiring) {
      where.add("date(expiry_date) <= date('now', '+7 days')");
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

  @override
  Future<Item?> getItem(String id) async {
    final db = await database;
    final rows =
        await db.query('items', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  @override
  Future<String> saveItem(Item item) async {
    final db = await database;
    await db.insert('items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return item.id;
  }

  @override
  Future<void> archiveItem(String itemId) async {
    final db = await database;
    await db.update(
      'items',
      {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('consumption_records',
          where: 'item_id = ?', whereArgs: [itemId]);
      await txn.delete('items', where: 'id = ?', whereArgs: [itemId]);
    });
  }

  @override
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

  @override
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

  @override
  Future<List<ConsumptionRecord>> getAllConsumptionRecords() async {
    final db = await database;
    final rows = await db.query(
      'consumption_records',
      orderBy: 'consumed_at DESC',
    );
    return rows.map(ConsumptionRecord.fromMap).toList();
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<LibraryStatistics> getStatistics() async {
    final db = await database;
    final rows = await db.rawQuery('''
SELECT
  COUNT(*) AS total_items,
      SUM(CASE WHEN expiry_date IS NULL OR date(expiry_date) >= date('now')
          THEN 1 ELSE 0 END) AS valid_items,
      SUM(CASE WHEN expiry_date IS NULL OR date(expiry_date) >= date('now')
          THEN COALESCE(purchase_price, 0) * remaining_quantity ELSE 0 END) AS total_spent
FROM items WHERE is_archived = 0
''');
    if (rows.isEmpty) {
      return LibraryStatistics.empty;
    }
    final row = rows.first;
    return LibraryStatistics(
      totalItems: ((row['total_items'] as num?) ?? 0).toInt(),
      validItems: ((row['valid_items'] as num?) ?? 0).toInt(),
      totalSpent: ((row['total_spent'] as num?) ?? 0).toDouble(),
    );
  }

  @override
  Future<String> exportToCsv() async {
    final categories = await getCategories();
    final items = await getItems();
    final rows = <List<Object?>>[
      [
        'type', 'id', 'name', 'category_id', 'icon', 'barcode', 'brand',
        'location', 'unit_price', 'purchase_date', 'expiry_date',
        'initial_quantity', 'remaining_quantity', 'track_daily_cost',
        'notes', 'created_at', 'updated_at', 'is_archived'
      ],
      ...categories.map((c) => [
            'category', c.id, c.name, '', c.icon, '', '', '', '', '', '', '',
            '', '', '', '', '', '',
          ]),
      ...items.map((i) => [
            'item', i.id, i.name, i.categoryId, i.icon, i.barcode, i.brand,
            i.defaultLocation, i.purchasePrice, i.purchaseDate?.toIso8601String(),
            i.expiryDate?.toIso8601String(), i.initialQuantity,
            i.remainingQuantity, i.trackDailyCost ? 1 : 0, i.notes,
            i.createdAt.toIso8601String(), i.updatedAt.toIso8601String(),
            i.isArchived ? 1 : 0,
          ]),
    ];
    return writeCsvToFile(rows);
  }

  @override
  Future<String> exportBackup() async {
    final backup = await buildBackupFile();
    return writeBackupToFile(backup.$1, backup.$2);
  }

  @override
  Future<(String fileName, String content)> buildBackupFile() async {
    final exportedAt = DateTime.now();
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
      buildBackupFileName(exportedAt),
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  @override
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
      await seedPresetCategories(db);
      await seedPresetLocations(db);
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

  @override
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

  @override
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('items');
      await txn.delete('consumption_records');
      await txn.delete('locations', where: 'is_active = 0');
      await txn.delete('categories', where: 'is_preset = 0');
    });
    await seedPresetCategories(db);
    await seedPresetLocations(db);
  }
}
