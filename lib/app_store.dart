import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repository.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.repository);

  final ItemRepository repository;

  bool isLoading = false;
  String? errorMessage;
  String homeSearch = '';
  String librarySearch = '';
  String? selectedCategoryId;
  List<Category> categories = [];
  List<ExpiryGroup> expiryGroups = [];
  List<ItemDisplay> libraryItems = [];
  LibraryStatistics statistics = LibraryStatistics.empty;

  Future<void> initialize() async {
    await _run(() async {
      await repository.initialize();
      await refreshAll();
    });
  }

  Future<void> refreshAll() async {
    categories = await repository.getCategories();
    expiryGroups = await repository.getExpiryGroups(searchText: homeSearch);
    libraryItems = await repository.getItemDisplays(
      query: ItemQuery(
        categoryId: selectedCategoryId,
        searchText: librarySearch,
        limit: 1000,
      ),
    );
    statistics = await repository.getStatistics();
    notifyListeners();
  }

  Future<void> setHomeSearch(String value) async {
    homeSearch = value;
    await _run(() async {
      expiryGroups = await repository.getExpiryGroups(searchText: homeSearch);
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
      libraryItems = await repository.getItemDisplays(
        query: ItemQuery(
          categoryId: selectedCategoryId,
          searchText: librarySearch,
          limit: 1000,
        ),
      );
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

  Future<void> addCategory(String name, String icon) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const StoreException('请填写分类名称');
    }
    final category = Category(
      id: newId(),
      name: trimmed,
      icon: icon.trim().isEmpty ? '🏷️' : icon.trim(),
      sortOrder: categories.length + 1,
      isPreset: false,
    );
    await _run(() async {
      await repository.saveCategory(category);
      await refreshAll();
    });
  }

  Future<void> deleteCategory(Category category) async {
    await _run(() async {
      await repository.deleteCategory(category);
      await refreshAll();
    });
  }

  Future<void> _run(Future<void> Function() action, {bool setLoading = true}) async {
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
