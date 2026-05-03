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
    Task<Item?> GetItemByIdAsync(Guid itemId);
    Task<Guid> SaveItemAsync(Item item);
    Task<int> DeleteItemAsync(Guid itemId);

    // DTO queries
    Task<ItemDisplayDto?> GetItemDisplayDtoByIdAsync(Guid itemId);
    Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync();
    Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync();
    Task<List<CategoryDto>> GetCategoryDtosAsync();
    Task<(decimal TotalSpent, int TotalItems, int ValidItems)> GetStatisticsAsync();

    // Combined query (avoids duplicate DB loads)
    Task<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)> GetItemsWithStatisticsAsync();

    // Excel export
    Task<string> ExportToExcelAsync();

    // Testing
    Task SeedSampleDataAsync();

    // Data management
    Task ClearAllDataAsync();
}
