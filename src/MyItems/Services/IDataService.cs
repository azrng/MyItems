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
    Task<bool> CategoryHasItemsAsync(Guid categoryId);

    // Item
    Task<List<Item>> GetItemsAsync();
    Task<Item?> GetItemByIdAsync(Guid itemId);
    Task<Guid> SaveItemAsync(Item item);
    Task<int> DeleteItemAsync(Guid itemId);

    // DTO queries
    Task<ItemDisplayDto?> GetItemDisplayDtoByIdAsync(Guid itemId);
    Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync();
    Task<PagedItemDisplayResult> GetItemDisplayPageAsync(ItemQueryOptions options);
    Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync();
    Task<List<CategoryDto>> GetCategoryDtosAsync();
    Task<(decimal TotalSpent, int TotalItems, int ValidItems)> GetStatisticsAsync();

    // Combined query (avoids duplicate DB loads)
    Task<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)> GetItemsWithStatisticsAsync();

    // CSV import/export
    Task<string> ExportToCsvAsync();
    Task<(int SuccessCount, int FailureCount, List<string> Errors)> ImportFromCsvAsync(string filePath);

    // Testing
    Task SeedSampleDataAsync();

    // Data management
    Task ClearAllDataAsync();

    // Database
    Task<int> GetDbVersionAsync();
    Task ImportDatabaseAsync(string sourcePath);
}

public sealed record ItemQueryOptions(
    int Offset,
    int Limit,
    Guid? CategoryId = null,
    string? SearchText = null,
    SearchFilter? AdvancedSearchFilter = null)
{
    public int SafeOffset => Math.Max(0, Offset);
    public int SafeLimit => Limit <= 0 ? 20 : Math.Min(Limit, 100);
}

public sealed record PagedItemDisplayResult(List<ItemDisplayDto> Items, int TotalCount);
