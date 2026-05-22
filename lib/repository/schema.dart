import 'package:sqflite/sqflite.dart';

import '../models.dart';

Future<void> createSchema(Database db) async {
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

Future<void> runPendingMigrations(Database db, {int fromVersion = 0}) async {
  final rows = await db.query('schema_migrations', columns: ['version']);
  final applied = rows.map((r) => (r['version'] as num).toInt()).toSet();
  if (!applied.contains(2)) {
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
}

Future<void> _addColumnIfMissing(
    Database db, String table, String column, String definition) async {
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  final exists = columns.any((row) => row['name'] == column);
  if (!exists) {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
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

Future<void> seedPresetCategories(Database db) async {
  for (final category in presetCategories) {
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

Future<void> seedPresetLocations(Database db) async {
  for (final location in presetLocations) {
    await db.insert(
      'locations',
      location.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
