enum ExpiryStatus {
  expired,
  expiring,
  safe,
  noExpiry,
}

enum LibraryStatusFilter {
  all,
  safe,
  expiring,
  expired,
}

enum ThemePreference {
  system('system', '跟随系统'),
  light('light', '浅色'),
  dark('dark', '深色');

  const ThemePreference(this.value, this.label);

  final String value;
  final String label;

  static ThemePreference fromValue(String? value) {
    return ThemePreference.values.firstWhere(
      (preference) => preference.value == value,
      orElse: () => ThemePreference.system,
    );
  }
}

enum ConsumptionType {
  consumeOne('consume_one', '用掉一件'),
  consumeAll('consume_all', '消耗完成');

  const ConsumptionType(this.value, this.label);

  final String value;
  final String label;

  static ConsumptionType fromValue(String? value) {
    return ConsumptionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ConsumptionType.consumeOne,
    );
  }
}

class StorageLocation {
  const StorageLocation({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
      };

  static StorageLocation fromMap(Map<String, Object?> map) => StorageLocation(
        id: map['id'] as String,
        name: map['name'] as String,
        sortOrder: (map['sort_order'] as num).toInt(),
        isActive: (map['is_active'] as num).toInt() == 1,
      );
}

class ConsumptionRecord {
  const ConsumptionRecord({
    required this.id,
    required this.itemId,
    required this.quantity,
    required this.type,
    required this.consumedAt,
  });

  final String id;
  final String itemId;
  final int quantity;
  final ConsumptionType type;
  final DateTime consumedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'item_id': itemId,
        'quantity': quantity,
        'type': type.value,
        'consumed_at': consumedAt.toIso8601String(),
      };

  static ConsumptionRecord fromMap(Map<String, Object?> map) =>
      ConsumptionRecord(
        id: map['id'] as String,
        itemId: map['item_id'] as String,
        quantity: (map['quantity'] as num).toInt(),
        type: ConsumptionType.fromValue(map['type'] as String?),
        consumedAt: parseDate(map['consumed_at'] as String?) ?? DateTime.now(),
      );
}

class ConsumptionRecordDisplay {
  const ConsumptionRecordDisplay({
    required this.record,
    required this.itemName,
  });

  final ConsumptionRecord record;
  final String itemName;
}

const _sentinel = Object();

class Category {
  const Category({
    required this.id,
    required this.name,
    this.icon,
    required this.sortOrder,
    required this.isPreset,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isPreset;
  final bool isActive;

  Category copyWith({
    String? id,
    String? name,
    Object? icon = _sentinel,
    int? sortOrder,
    bool? isPreset,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: identical(icon, _sentinel) ? this.icon : icon as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      isPreset: isPreset ?? this.isPreset,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'sort_order': sortOrder,
        'is_preset': isPreset ? 1 : 0,
        'is_active': isActive ? 1 : 0,
      };

  static Category fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String?,
        sortOrder: (map['sort_order'] as num).toInt(),
        isPreset: (map['is_preset'] as num).toInt() == 1,
        isActive: (map['is_active'] as num).toInt() == 1,
      );
}

class Item {
  const Item({
    required this.id,
    required this.name,
    required this.categoryId,
    this.barcode,
    this.brand,
    this.icon,
    this.defaultLocation,
    this.isArchived = false,
    this.purchaseDate,
    this.purchasePrice,
    this.expiryDate,
    this.quantity = 1,
    int? initialQuantity,
    int? remainingQuantity,
    this.trackDailyCost = false,
    this.notes,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  })  : initialQuantity = initialQuantity ?? quantity,
        remainingQuantity = remainingQuantity ?? quantity;

  final String id;
  final String name;
  final String categoryId;
  final String? barcode;
  final String? brand;
  final String? icon;
  final String? defaultLocation;
  final bool isArchived;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final DateTime? expiryDate;
  final int quantity;
  final int initialQuantity;
  final int remainingQuantity;
  final bool trackDailyCost;
  final String? notes;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Item copyWith({
    String? id,
    String? name,
    String? categoryId,
    Object? barcode = _sentinel,
    Object? brand = _sentinel,
    Object? icon = _sentinel,
    Object? defaultLocation = _sentinel,
    bool? isArchived,
    DateTime? purchaseDate,
    double? purchasePrice,
    Object? expiryDate = _sentinel,
    int? quantity,
    int? initialQuantity,
    int? remainingQuantity,
    bool? trackDailyCost,
    Object? notes = _sentinel,
    Object? imagePath = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      barcode: identical(barcode, _sentinel) ? this.barcode : barcode as String?,
      brand: identical(brand, _sentinel) ? this.brand : brand as String?,
      icon: identical(icon, _sentinel) ? this.icon : icon as String?,
      defaultLocation: identical(defaultLocation, _sentinel) ? this.defaultLocation : defaultLocation as String?,
      isArchived: isArchived ?? this.isArchived,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      expiryDate: identical(expiryDate, _sentinel) ? this.expiryDate : expiryDate as DateTime?,
      quantity: quantity ?? this.quantity,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      trackDailyCost: trackDailyCost ?? this.trackDailyCost,
      notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      imagePath: identical(imagePath, _sentinel) ? this.imagePath : imagePath as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category_id': categoryId,
        'barcode': barcode,
        'brand': brand,
        'icon': icon,
        'default_location': defaultLocation,
        'is_archived': isArchived ? 1 : 0,
        'purchase_date': purchaseDate?.toIso8601String(),
        'purchase_price': purchasePrice,
        'expiry_date': expiryDate?.toIso8601String(),
        'quantity': quantity,
        'initial_quantity': initialQuantity,
        'remaining_quantity': remainingQuantity,
        'track_daily_cost': trackDailyCost ? 1 : 0,
        'notes': notes,
        'image_path': imagePath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static Item fromMap(Map<String, Object?> map) => Item(
        id: map['id'] as String,
        name: map['name'] as String,
        categoryId: map['category_id'] as String,
        barcode: map['barcode'] as String?,
        brand: map['brand'] as String?,
        icon: map['icon'] as String?,
        defaultLocation: map['default_location'] as String?,
        isArchived: (map['is_archived'] as num).toInt() == 1,
        purchaseDate: parseDate(map['purchase_date'] as String?),
        purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
        expiryDate: parseDate(map['expiry_date'] as String?),
        quantity: (map['quantity'] as num).toInt(),
        initialQuantity:
            ((map['initial_quantity'] ?? map['quantity']) as num).toInt(),
        remainingQuantity:
            ((map['remaining_quantity'] ?? map['quantity']) as num).toInt(),
        trackDailyCost: (map['track_daily_cost'] as num).toInt() == 1,
        notes: map['notes'] as String?,
        imagePath: map['image_path'] as String?,
        createdAt: parseDate(map['created_at'] as String?) ?? DateTime.now(),
        updatedAt: parseDate(map['updated_at'] as String?) ?? DateTime.now(),
      );
}

class ItemDisplay {
  const ItemDisplay({
    required this.item,
    required this.category,
    required this.expiryStatus,
    required this.expiryStatusText,
    required this.holdingDays,
    required this.dailyCost,
    required this.dailyCostText,
    required this.holdingText,
  });

  final Item item;
  final Category category;
  final ExpiryStatus expiryStatus;
  final String expiryStatusText;
  final int holdingDays;
  final double dailyCost;
  final String dailyCostText;
  final String holdingText;

  String get id => item.id;
  String get name => item.name;
  String get categoryName => category.name;
  String get categoryIcon => category.icon ?? '📦';
  String get locationDisplay => emptyToFallback(item.defaultLocation, '未填写');
  String get brandDisplay => emptyToFallback(item.brand, '未填写');
  String get priceText =>
      item.purchasePrice == null ? '未记录' : formatCurrency(item.purchasePrice!);
  String get stockText =>
      '剩余 ${item.remainingQuantity}/${item.initialQuantity} 件';
  String get expiryDateText =>
      item.expiryDate == null ? '无保质期' : formatDate(item.expiryDate!);
  String get notesDisplay => emptyToFallback(item.notes, '暂无备注');

  static ItemDisplay fromItem({
    required Item item,
    required Category category,
    DateTime? today,
  }) {
    final baseDate = dateOnly(today ?? DateTime.now());
    final status = calculateExpiryStatus(item.expiryDate, baseDate);
    final holdingDays = getHoldingDays(item.purchaseDate, baseDate);
    final dailyCost = calculateDailyCost(
        item.purchasePrice, item.quantity, item.purchaseDate, baseDate);

    return ItemDisplay(
      item: item,
      category: category,
      expiryStatus: status,
      expiryStatusText: getExpiryStatusText(status, item.expiryDate, baseDate),
      holdingDays: holdingDays,
      dailyCost: dailyCost,
      dailyCostText:
          item.trackDailyCost ? '¥${dailyCost.toStringAsFixed(2)}/天' : '',
      holdingText: holdingDays == 0 ? '今天购入' : '持有 $holdingDays 天',
    );
  }

  bool matchesKeyword(String keyword) {
    final value = keyword.trim().toLowerCase();
    if (value.isEmpty) return true;
    return [
      item.name,
      item.brand,
      item.defaultLocation,
      item.barcode,
      category.name,
    ].whereType<String>().any((field) => field.toLowerCase().contains(value));
  }
}

class ExpiryGroup {
  const ExpiryGroup({
    required this.status,
    required this.title,
    required this.icon,
    required this.items,
    this.isExpanded = true,
  });

  final ExpiryStatus status;
  final String title;
  final String icon;
  final List<ItemDisplay> items;
  final bool isExpanded;

  String get headerText => '$title (${items.length})';
}

class LibraryStatistics {
  const LibraryStatistics({
    required this.totalSpent,
    required this.totalItems,
    required this.validItems,
  });

  final double totalSpent;
  final int totalItems;
  final int validItems;

  static const empty =
      LibraryStatistics(totalSpent: 0, totalItems: 0, validItems: 0);
}

class ItemQuery {
  const ItemQuery({
    this.offset = 0,
    this.limit = 30,
    this.categoryId,
    this.searchText,
    this.onlyExpiring = false,
    this.onlyExpired = false,
    this.hasExpiry = false,
  });

  final int offset;
  final int limit;
  final String? categoryId;
  final String? searchText;
  final bool onlyExpiring;
  final bool onlyExpired;
  final bool hasExpiry;
}

ExpiryStatus calculateExpiryStatus(DateTime? expiryDate, [DateTime? today]) {
  if (expiryDate == null) return ExpiryStatus.noExpiry;
  final baseDate = dateOnly(today ?? DateTime.now());
  final expiry = dateOnly(expiryDate);
  if (expiry.isBefore(baseDate)) return ExpiryStatus.expired;
  if (!expiry.isAfter(baseDate.add(const Duration(days: 7)))) {
    return ExpiryStatus.expiring;
  }
  return ExpiryStatus.safe;
}

String getExpiryStatusText(ExpiryStatus status, DateTime? expiryDate,
    [DateTime? today]) {
  final baseDate = dateOnly(today ?? DateTime.now());
  final expiry = expiryDate == null ? null : dateOnly(expiryDate);
  switch (status) {
    case ExpiryStatus.expired:
      return expiry == null
          ? '已过期'
          : '过期 ${baseDate.difference(expiry).inDays} 天';
    case ExpiryStatus.expiring:
      return expiry == null
          ? '临期'
          : '临期 ${expiry.difference(baseDate).inDays} 天';
    case ExpiryStatus.safe:
    case ExpiryStatus.noExpiry:
      return '';
  }
}

String getGroupTitle(ExpiryStatus status) => switch (status) {
      ExpiryStatus.expired => '已过期',
      ExpiryStatus.expiring => '临期',
      ExpiryStatus.safe => '安全',
      ExpiryStatus.noExpiry => '无保质期',
    };

String getGroupIcon(ExpiryStatus status) => switch (status) {
      ExpiryStatus.expired => '🔴',
      ExpiryStatus.expiring => '🟡',
      ExpiryStatus.safe => '🟢',
      ExpiryStatus.noExpiry => '🔵',
    };

int getHoldingDays(DateTime? purchaseDate, [DateTime? today]) {
  if (purchaseDate == null) return 0;
  final days = dateOnly(today ?? DateTime.now())
      .difference(dateOnly(purchaseDate))
      .inDays;
  return days > 0 ? days : 1;
}

double calculateDailyCost(double? price, int quantity, DateTime? purchaseDate,
    [DateTime? today]) {
  if (price == null || purchaseDate == null) return 0;
  final days = getHoldingDays(purchaseDate, today);
  if (days <= 0) return price;
  return price / days;
}

String formatCurrency(double value) => '¥${value.toStringAsFixed(2)}';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime? parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String formatDate(DateTime value) {
  return '${value.year}年${value.month}月${value.day}日';
}

String emptyToFallback(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

String newId() {
  final ms = DateTime.now().microsecondsSinceEpoch;
  final rand = DateTime.now().millisecondsSinceEpoch.hashCode ^ ms;
  return '${ms}_${(rand & 0xFFFFFF).toRadixString(36).padLeft(5, '0')}';
}
