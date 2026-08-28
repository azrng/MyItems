import 'package:drift/drift.dart';

/// 全部表定义（requirement.md §3 数据模型，全新基线 schema v1）。

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get colorKey => text().withDefault(const Constant('accent'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class StorageLocations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get region => text().withDefault(const Constant('其他区域'))();
  TextColumn get icon => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 物品（Item/Batch 拆分后的主档）。
/// reminderEnabled 为 §2.1/§5.6「物品级提醒开关（默认开）」补充列。
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get spec => text().nullable()();
  TextColumn get categoryId => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isConsumable => boolean().withDefault(const Constant(true))();
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get lastLocationId => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Batch')
class Batches extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get openedAt => dateTime().nullable()();
  IntColumn get openShelfLifeDays => integer().nullable()();
  TextColumn get locationId => text().nullable()();
  RealColumn get initialQuantity => real().withDefault(const Constant(1))();
  RealColumn get remainingQuantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('件'))();
  TextColumn get notes => text().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get batchLabel => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 库存流水：intake / open / consume / archive / adjust（requirement.md §3.5）。
class InventoryLogs extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get batchId => text().nullable()();
  TextColumn get type => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  TextColumn get locationText => text().nullable()();
  TextColumn get source => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 回购清单：status = 待购 / 已在购物车。
class RepurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get status => text().withDefault(const Constant('待购'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// KV 设置（requirement.md §3.7）。
class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
