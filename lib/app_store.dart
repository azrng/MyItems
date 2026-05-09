import 'package:flutter/foundation.dart' hide Category;

import 'models.dart';
import 'repository.dart';

const defaultCategoryIconValue = '🏷️';

class AppStore extends ChangeNotifier {
  AppStore(this.repository);

  final ItemRepository repository;

  bool isLoading = false;
  String? errorMessage;
  String homeSearch = '';
  String expirySearch = '';
  String librarySearch = '';
  String? selectedCategoryId;
  List<Category> categories = [];
  List<StorageLocation> locations = [];
  List<ItemDisplay> homeItems = [];
  List<ExpiryGroup> expiryGroups = [];
  List<ItemDisplay> libraryItems = [];
  LibraryStatistics statistics = LibraryStatistics.empty;
  ThemePreference themePreference = ThemePreference.system;

  Future<void> initialize() async {
    await _run(() async {
      await repository.initialize();
      themePreference = await repository.getThemePreference();
      await refreshAll();
    });
  }

  Future<void> setThemePreference(ThemePreference preference) async {
    themePreference = preference;
    notifyListeners();
    await repository.saveThemePreference(preference);
  }

  Future<void> refreshAll() async {
    categories = await repository.getCategories();
    locations = await repository.getLocations();
    homeItems = await repository.getHomeItemDisplays(searchText: homeSearch);
    expiryGroups = _sortExpiryGroupsByExpiryAsc(
        await repository.getExpiryGroups(searchText: expirySearch));
    libraryItems = _sortByCreatedDesc(await repository.getItemDisplays(
      query: ItemQuery(
        categoryId: selectedCategoryId,
        searchText: librarySearch,
        limit: 1000,
      ),
    ));
    statistics = await repository.getStatistics();
    notifyListeners();
  }

  Future<void> setHomeSearch(String value) async {
    homeSearch = value;
    await _run(() async {
      homeItems = await repository.getHomeItemDisplays(searchText: homeSearch);
      notifyListeners();
    }, setLoading: false);
  }

  Future<void> setExpirySearch(String value) async {
    expirySearch = value;
    await _run(() async {
      expiryGroups = _sortExpiryGroupsByExpiryAsc(
          await repository.getExpiryGroups(searchText: expirySearch));
      notifyListeners();
    }, setLoading: false);
  }

  Future<void> setLibrarySearch(String value) async {
    librarySearch = value;
    await refreshLibrary(setLoading: false);
  }

  Future<void> selectCategory(String? categoryId) async {
    selectedCategoryId = categoryId;
    await refreshLibrary(setLoading: false);
  }

  Future<void> refreshLibrary({bool setLoading = true}) async {
    await _run(() async {
      libraryItems = _sortByCreatedDesc(await repository.getItemDisplays(
        query: ItemQuery(
          categoryId: selectedCategoryId,
          searchText: librarySearch,
          limit: 1000,
        ),
      ));
      statistics = await repository.getStatistics();
      notifyListeners();
    }, setLoading: setLoading);
  }

  Future<Item?> getItem(String id) => repository.getItem(id);

  Category? categoryById(String? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<String> saveItemFromForm(ItemFormData form) async {
    if (form.name.trim().isEmpty) {
      throw const StoreException('请填写物品名称');
    }
    if (form.categoryId == null || form.categoryId!.isEmpty) {
      throw const StoreException('请选择分类');
    }

    final now = DateTime.now();
    final item = Item(
      id: form.id ?? newId(),
      name: form.name.trim(),
      categoryId: form.categoryId!,
      barcode: emptyStringToNull(form.barcode),
      brand: emptyStringToNull(form.brand),
      icon: categoryById(form.categoryId)?.icon,
      defaultLocation: emptyStringToNull(form.location),
      purchaseDate: form.purchaseDate,
      purchasePrice: form.purchasePrice,
      expiryDate: form.noExpiry ? null : form.expiryDate,
      quantity: form.quantity < 1 ? 1 : form.quantity,
      initialQuantity: form.quantity < 1 ? 1 : form.quantity,
      remainingQuantity:
          form.remainingQuantity ?? (form.quantity < 1 ? 1 : form.quantity),
      trackDailyCost: form.trackDailyCost,
      notes: emptyStringToNull(form.notes),
      createdAt: form.createdAt ?? now,
      updatedAt: now,
    );

    final id = await repository.saveItem(item);
    await refreshAll();
    return id;
  }

  Future<void> archiveItem(String itemId) async {
    await _run(() async {
      await repository.archiveItem(itemId);
      await refreshAll();
    });
  }

  Future<void> deleteItem(String itemId) async {
    await _run(() async {
      await repository.deleteItem(itemId);
      await refreshAll();
    });
  }

  Future<void> consumeOne(String itemId) async {
    await _run(() async {
      await repository.consumeItem(
        itemId,
        quantity: 1,
        type: ConsumptionType.consumeOne,
      );
      await refreshAll();
    });
  }

  Future<void> consumeAll(String itemId) async {
    final item = await repository.getItem(itemId);
    if (item == null) {
      throw const StoreException('物品不存在');
    }
    await _run(() async {
      await repository.consumeItem(
        itemId,
        quantity: item.remainingQuantity,
        type: ConsumptionType.consumeAll,
      );
      await refreshAll();
    });
  }

  Future<List<ConsumptionRecord>> getConsumptionRecords(String itemId) {
    return repository.getConsumptionRecords(itemId);
  }

  Future<void> addCategory(String name, String icon) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const StoreException('请填写分类名称');
    }
    final category = Category(
      id: newId(),
      name: trimmed,
      icon: icon.trim().isEmpty ? defaultCategoryIconValue : icon.trim(),
      sortOrder: categories.length + 1,
      isPreset: false,
    );
    await _run(() async {
      await repository.saveCategory(category);
      await refreshAll();
    });
  }

  Future<void> renameCategory(
      Category category, String name, String icon) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const StoreException('请填写分类名称');
    }
    await _run(() async {
      await repository.renameCategory(
        category,
        trimmed,
        icon.trim().isEmpty ? defaultCategoryIconValue : icon.trim(),
      );
      await refreshAll();
    });
  }

  Future<void> addLocation(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const StoreException('请填写位置名称');
    }
    final location = StorageLocation(
      id: newId(),
      name: trimmed,
      sortOrder: locations.length + 1,
    );
    await _run(() async {
      await repository.saveLocation(location);
      await refreshAll();
    });
  }

  Future<void> renameLocation(StorageLocation location, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const StoreException('请填写位置名称');
    }
    await _run(() async {
      await repository.renameLocation(location.id, trimmed);
      await refreshAll();
    });
  }

  Future<void> deleteLocation(StorageLocation location) async {
    await _run(() async {
      await repository.deleteLocation(location);
      await refreshAll();
    });
  }

  Future<void> reorderCategory(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= categories.length) return;
    final nextCategories = List<Category>.of(categories);
    var targetIndex = newIndex;
    if (targetIndex > nextCategories.length) {
      targetIndex = nextCategories.length;
    }
    if (oldIndex < targetIndex) targetIndex -= 1;
    final moved = nextCategories.removeAt(oldIndex);
    nextCategories.insert(targetIndex, moved);

    categories = [
      for (var index = 0; index < nextCategories.length; index++)
        nextCategories[index].copyWith(sortOrder: index + 1),
    ];
    notifyListeners();
    await _run(() async {
      await repository.updateCategoryOrder(categories);
      await refreshAll();
    }, setLoading: false);
  }

  Future<void> deleteCategory(Category category) async {
    await _run(() async {
      await repository.deleteCategory(category);
      await refreshAll();
    });
  }

  Future<String> exportToCsv() => repository.exportToCsv();

  Future<(int successCount, int failureCount, List<String> errors)>
      importFromCsv(String filePath) async {
    final result = await repository.importFromCsv(filePath);
    await refreshAll();
    return result;
  }

  Future<void> clearAllData() async {
    await _run(() async {
      await repository.clearAllData();
      await refreshAll();
    });
  }

  Future<void> _run(Future<void> Function() action,
      {bool setLoading = true}) async {
    try {
      if (setLoading) {
        isLoading = true;
        notifyListeners();
      }
      errorMessage = null;
      await action();
    } on StoreException catch (error) {
      errorMessage = error.message;
      rethrow;
    } on RepositoryException catch (error) {
      errorMessage = error.message;
      rethrow;
    } catch (error) {
      errorMessage = '操作失败：$error';
      rethrow;
    } finally {
      if (setLoading) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  List<ItemDisplay> _sortByCreatedDesc(List<ItemDisplay> items) {
    return [...items]
      ..sort((a, b) => b.item.createdAt.compareTo(a.item.createdAt));
  }

  List<ExpiryGroup> _sortExpiryGroupsByExpiryAsc(List<ExpiryGroup> groups) {
    return groups
        .map((group) => ExpiryGroup(
              status: group.status,
              title: group.title,
              icon: group.icon,
              isExpanded: group.isExpanded,
              items: [...group.items]..sort((a, b) {
                  final aExpiry = a.item.expiryDate ?? DateTime(9999);
                  final bExpiry = b.item.expiryDate ?? DateTime(9999);
                  return aExpiry.compareTo(bExpiry);
                }),
            ))
        .toList();
  }
}

class ItemFormData {
  ItemFormData({
    this.id,
    this.name = '',
    this.categoryId,
    this.barcode,
    this.brand,
    this.location,
    this.purchaseDate,
    this.purchasePrice,
    DateTime? expiryDate,
    this.noExpiry = false,
    this.quantity = 1,
    this.remainingQuantity,
    this.trackDailyCost = false,
    this.notes,
    this.createdAt,
  }) : expiryDate = expiryDate ?? DateTime.now().add(const Duration(days: 30));

  String? id;
  String name;
  String? categoryId;
  String? barcode;
  String? brand;
  String? location;
  DateTime? purchaseDate;
  double? purchasePrice;
  DateTime? expiryDate;
  bool noExpiry;
  int quantity;
  int? remainingQuantity;
  bool trackDailyCost;
  String? notes;
  DateTime? createdAt;

  static ItemFormData fromItem(Item item) => ItemFormData(
        id: item.id,
        name: item.name,
        categoryId: item.categoryId,
        barcode: item.barcode,
        brand: item.brand,
        location: item.defaultLocation,
        purchaseDate: item.purchaseDate,
        purchasePrice: item.purchasePrice,
        expiryDate: item.expiryDate,
        noExpiry: item.expiryDate == null,
        quantity: item.quantity,
        remainingQuantity: item.remainingQuantity,
        trackDailyCost: item.trackDailyCost,
        notes: item.notes,
        createdAt: item.createdAt,
      );
}

class StoreException implements Exception {
  const StoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
