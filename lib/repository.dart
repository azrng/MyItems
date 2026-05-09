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
      version: 1,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedPresetCategories(db);
      },
      onOpen: (db) async {
        await _createSchema(db);
        await _seedPresetCategories(db);
      },
    );
    return _database!;
  }

  Future<void> initialize() async {
    await database;
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
  track_daily_cost INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  image_path TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_archived ON items(is_archived)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_expiry ON items(expiry_date)');
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

  Future<List<Category>> getCategories() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: 'is_active = 1',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<void> saveCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    await db.update('categories', {'is_active': 0}, where: 'id = ?', whereArgs: [category.id]);
  }

  Future<List<Item>> getItems() async {
    final db = await database;
    final rows = await db.query(
      'items',
      where: 'is_archived = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Item.fromMap).toList();
  }

  Future<Item?> getItem(String id) async {
    final db = await database;
    final rows = await db.query('items', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  Future<String> saveItem(Item item) async {
    final db = await database;
    await db.insert('items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<List<ItemDisplay>> getItemDisplays({ItemQuery query = const ItemQuery()}) async {
    final categories = await getCategories();
    final lookup = {for (final category in categories) category.id: category};
    final items = await getItems();
    final displays = items
        .where((item) => query.categoryId == null || item.categoryId == query.categoryId)
        .map((item) => ItemDisplay.fromItem(
              item: item,
              category: lookup[item.categoryId] ?? fallbackCategory,
            ))
        .where((display) => display.matchesKeyword(query.searchText ?? ''))
        .where((display) => !query.hasExpiry || display.item.expiryDate != null)
        .where((display) => !query.onlyExpired || display.expiryStatus == ExpiryStatus.expired)
        .where((display) =>
            !query.onlyExpiring ||
            display.expiryStatus == ExpiryStatus.expired ||
            display.expiryStatus == ExpiryStatus.expiring)
        .toList();

    displays.sort((a, b) {
      final status = a.expiryStatus.index.compareTo(b.expiryStatus.index);
      if (status != 0) return status;
      final aExpiry = a.item.expiryDate ?? DateTime(9999);
      final bExpiry = b.item.expiryDate ?? DateTime(9999);
      return aExpiry.compareTo(bExpiry);
    });

    return displays.skip(query.offset).take(query.limit).toList();
  }

  Future<List<ItemDisplay>> getHomeItemDisplays({String? searchText, int limit = 1000}) async {
    final categories = await getCategories();
    final lookup = {for (final category in categories) category.id: category};
    final displays = (await getItems())
        .map((item) => ItemDisplay.fromItem(
              item: item,
              category: lookup[item.categoryId] ?? fallbackCategory,
            ))
        .where((display) => display.matchesKeyword(searchText ?? ''))
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
              items: displays.where((item) => item.expiryStatus == status).toList(),
            ))
        .toList();
  }

  Future<LibraryStatistics> getStatistics() async {
    final displays = await getItemDisplays(query: const ItemQuery(limit: 10000));
    final valid = displays
        .where((item) => item.expiryStatus != ExpiryStatus.expired)
        .fold<double>(0, (sum, item) => sum + (item.item.purchasePrice ?? 0) * item.item.quantity);
    final validCount = displays.where((item) => item.expiryStatus != ExpiryStatus.expired).length;
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
      ['type', 'id', 'name', 'category_id', 'icon', 'brand', 'location', 'price', 'expiry_date', 'quantity', 'notes'],
      ...categories.map((c) => ['category', c.id, c.name, '', c.icon, '', '', '', '', '', '']),
      ...items.map((i) => [
            'item',
            i.id,
            i.name,
            i.categoryId,
            i.icon,
            i.brand,
            i.defaultLocation,
            i.purchasePrice,
            i.expiryDate?.toIso8601String(),
            i.quantity,
            i.notes,
          ]),
    ];
    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return file.path;
  }

  Future<(int successCount, int failureCount, List<String> errors)> importFromCsv(String filePath) async {
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
    for (final row in rows.skip(1)) {
      try {
        if (row.isEmpty) continue;
        if (row[0] == 'category') {
          await saveCategory(Category(
            id: row[1].toString(),
            name: row[2].toString(),
            icon: row[4]?.toString(),
            sortOrder: 100 + success,
            isPreset: false,
          ));
          success++;
        } else if (row[0] == 'item') {
          final now = DateTime.now();
          await saveItem(Item(
            id: row[1].toString(),
            name: row[2].toString(),
            categoryId: row[3].toString(),
            icon: emptyStringToNull(row[4]?.toString()),
            brand: emptyStringToNull(row[5]?.toString()),
            defaultLocation: emptyStringToNull(row[6]?.toString()),
            purchasePrice: double.tryParse(row[7]?.toString() ?? ''),
            expiryDate: parseDate(row[8]?.toString()),
            quantity: int.tryParse(row[9]?.toString() ?? '') ?? 1,
            notes: emptyStringToNull(row[10]?.toString()),
            createdAt: now,
            updatedAt: now,
          ));
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
    await db.delete('categories', where: 'is_preset = 0');
    await _seedPresetCategories(db);
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

const fallbackCategory = Category(
  id: 'other',
  name: '其他',
  icon: '📦',
  sortOrder: 999,
  isPreset: true,
);

const presetCategories = [
  Category(id: 'food', name: '食品/饮料', icon: '🍔', sortOrder: 1, isPreset: true),
  Category(id: 'beauty', name: '化妆品/护肤品', icon: '💄', sortOrder: 2, isPreset: true),
  Category(id: 'medicine', name: '药品/保健品', icon: '💊', sortOrder: 3, isPreset: true),
  Category(id: 'daily', name: '日用品', icon: '🧴', sortOrder: 4, isPreset: true),
  Category(id: 'electronics', name: '电子产品', icon: '💻', sortOrder: 5, isPreset: true),
  fallbackCategory,
];
