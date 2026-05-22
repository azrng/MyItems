import '../models.dart';

abstract class ItemRepository {
  Future<void> initialize();
  Future<ThemePreference> getThemePreference();
  Future<void> saveThemePreference(ThemePreference preference);
  Future<List<Category>> getCategories({bool includeInactive = false});
  Future<void> saveCategory(Category category);
  Future<void> renameCategory(Category category, String name, String icon);
  Future<void> updateCategoryOrder(List<Category> categories);
  Future<bool> categoryHasItems(String categoryId);
  Future<void> deleteCategory(Category category);
  Future<List<StorageLocation>> getLocations({bool includeInactive = false});
  Future<void> saveLocation(StorageLocation location);
  Future<void> renameLocation(String locationId, String name);
  Future<void> deleteLocation(StorageLocation location);
  Future<List<Item>> getItems({
    ItemQuery query = const ItemQuery(),
    bool includeArchived = false,
  });
  Future<Item?> getItem(String id);
  Future<String> saveItem(Item item);
  Future<void> archiveItem(String itemId);
  Future<void> deleteItem(String itemId);
  Future<void> consumeItem(String itemId,
      {required int quantity, required ConsumptionType type});
  Future<List<ConsumptionRecord>> getConsumptionRecords(String itemId);
  Future<List<ConsumptionRecord>> getAllConsumptionRecords();
  Future<List<ConsumptionRecordDisplay>> getConsumptionRecordDisplays();
  Future<List<ItemDisplay>> getItemDisplays({ItemQuery query = const ItemQuery()});
  Future<List<ItemDisplay>> getArchivedItemDisplays();
  Future<List<ItemDisplay>> getHomeItemDisplays(
      {String? searchText, int limit = 1000});
  Future<List<ExpiryGroup>> getExpiryGroups({String? searchText});
  Future<LibraryStatistics> getStatistics();
  Future<String> exportToCsv();
  Future<String> exportBackup();
  Future<(String fileName, String content)> buildBackupFile();
  Future<(int successCount, int failureCount, List<String> errors)>
      importBackup(String filePath);
  Future<(int successCount, int failureCount, List<String> errors)>
      importFromCsv(String filePath);
  Future<void> clearAllData();
}
