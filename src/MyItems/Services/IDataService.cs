using MyItems.Models;
using MyItems.Models.DTOs;

namespace MyItems.Services;

public interface IDataService
{
    Task InitializeAsync();

    // Category
    Task<List<Category>> GetCategoriesAsync();
    Task<int> SaveCategoryAsync(Category category);
    Task<int> DeleteCategoryAsync(Category category);

    // Item
    Task<List<Item>> GetItemsAsync();
    Task<Guid> SaveItemAsync(Item item);
    Task<int> ArchiveItemAsync(Guid itemId);

    // Batch
    Task<List<Batch>> GetBatchesAsync();
    Task<int> SaveBatchAsync(Batch batch);
    Task<int> DeleteBatchAsync(Guid batchId);

    // DTO queries
    Task<List<BatchDisplayDto>> GetBatchDisplayDtosAsync();
    Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync();
    Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync();
    Task<List<CategoryDto>> GetCategoryDtosAsync();
    Task<(decimal TotalSpent, int TotalBatches, int ValidBatches)> GetStatisticsAsync();

    // Excel export
    Task<string> ExportToExcelAsync();

    // Testing
    Task SeedSampleDataAsync();

    // Data management
    Task ClearAllDataAsync();
}
