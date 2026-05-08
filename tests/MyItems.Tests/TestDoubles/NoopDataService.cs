using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.Tests;

public class NoopDataService : IDataService
{
    public Task InitializeAsync() => Task.CompletedTask;
    public Task<List<Category>> GetCategoriesAsync() => Task.FromResult(new List<Category>());
    public Task<int> SaveCategoryAsync(Category category) => Task.FromResult(1);
    public Task<int> DeleteCategoryAsync(Category category) => Task.FromResult(1);
    public Task<bool> CategoryHasItemsAsync(Guid categoryId) => Task.FromResult(false);
    public Task<List<Item>> GetItemsAsync() => Task.FromResult(new List<Item>());
    public Task<Item?> GetItemByIdAsync(Guid itemId) => Task.FromResult<Item?>(null);
    public Task<Guid> SaveItemAsync(Item item) => Task.FromResult(item.Id);
    public Task<int> DeleteItemAsync(Guid itemId) => Task.FromResult(1);
    public Task<ItemDisplayDto?> GetItemDisplayDtoByIdAsync(Guid itemId) => Task.FromResult<ItemDisplayDto?>(null);
    public Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync() => Task.FromResult(new List<ItemDisplayDto>());
    public virtual Task<PagedItemDisplayResult> GetItemDisplayPageAsync(ItemQueryOptions options)
    {
        return Task.FromResult(new PagedItemDisplayResult(new List<ItemDisplayDto>(), 0));
    }

    public Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync() => Task.FromResult(new List<ExpiryGroupDto>());
    public Task<List<CategoryDto>> GetCategoryDtosAsync() => Task.FromResult(new List<CategoryDto>());
    public Task<(decimal TotalSpent, int TotalItems, int ValidItems)> GetStatisticsAsync() => Task.FromResult((0m, 0, 0));
    public Task<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)> GetItemsWithStatisticsAsync()
    {
        return Task.FromResult((new List<ItemDisplayDto>(), 0m, 0, 0));
    }

    public Task<string> ExportToCsvAsync() => Task.FromResult(string.Empty);
    public Task<(int SuccessCount, int FailureCount, List<string> Errors)> ImportFromCsvAsync(string filePath)
    {
        return Task.FromResult((0, 0, new List<string>()));
    }

    public Task SeedSampleDataAsync() => Task.CompletedTask;
    public Task ClearAllDataAsync() => Task.CompletedTask;
    public Task<int> GetDbVersionAsync() => Task.FromResult(0);
    public Task ImportDatabaseAsync(string sourcePath) => Task.CompletedTask;
}
