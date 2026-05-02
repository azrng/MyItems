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
    Task<int> DeleteItemAsync(Guid itemId);

    // DTO queries
    Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync();
    Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync();
    Task<List<CategoryDto>> GetCategoryDtosAsync();
    Task<(decimal TotalSpent, int TotalItems, int ValidItems)> GetStatisticsAsync();

    // Excel export
    Task<string> ExportToExcelAsync();

    // Testing
    Task SeedSampleDataAsync();

    // Data management
    Task ClearAllDataAsync();
}
