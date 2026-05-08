using MyItems.Enums;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;
using Xunit;

namespace MyItems.Tests.Services;

public sealed class ItemQueryCacheTests
{
    [Fact]
    public async Task GetSnapshotAsync_ReusesLoadedSnapshot_UntilInvalidated()
    {
        var dataService = new CountingDataService();
        var cache = new ItemQueryCache(dataService);

        var first = await cache.GetSnapshotAsync();
        var second = await cache.GetSnapshotAsync();
        cache.Invalidate();
        var third = await cache.GetSnapshotAsync();

        Assert.Same(first, second);
        Assert.NotSame(second, third);
        Assert.Equal(2, dataService.LoadCount);
    }

    [Fact]
    public async Task GetSnapshotAsync_CoalescesConcurrentLoads()
    {
        var releaseLoad = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var dataService = new CountingDataService
        {
            BeforeReturnAsync = () => releaseLoad.Task,
        };
        var cache = new ItemQueryCache(dataService);

        var first = cache.GetSnapshotAsync();
        var second = cache.GetSnapshotAsync();
        releaseLoad.SetResult();
        await Task.WhenAll(first, second);

        Assert.Same(await first, await second);
        Assert.Equal(1, dataService.LoadCount);
    }

    private sealed class CountingDataService : IDataService
    {
        public int LoadCount { get; private set; }
        public Func<Task>? BeforeReturnAsync { get; init; }

        public async Task<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)> GetItemsWithStatisticsAsync()
        {
            LoadCount++;
            if (BeforeReturnAsync is not null)
                await BeforeReturnAsync();

            var item = new ItemDisplayDto
            {
                ItemId = Guid.NewGuid(),
                ItemName = $"物品 {LoadCount}",
                Quantity = 1,
                PurchasePrice = 10,
                ExpiryStatus = ExpiryStatus.Safe,
            };

            return ([item], 10, 1, 1);
        }

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
        public Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync() => Task.FromResult(new List<ExpiryGroupDto>());
        public Task<List<CategoryDto>> GetCategoryDtosAsync() => Task.FromResult(new List<CategoryDto>());
        public Task<(decimal TotalSpent, int TotalItems, int ValidItems)> GetStatisticsAsync() => Task.FromResult((0m, 0, 0));
        public Task<string> ExportToCsvAsync() => Task.FromResult(string.Empty);
        public Task<(int SuccessCount, int FailureCount, List<string> Errors)> ImportFromCsvAsync(string filePath) => Task.FromResult((0, 0, new List<string>()));
        public Task SeedSampleDataAsync() => Task.CompletedTask;
        public Task ClearAllDataAsync() => Task.CompletedTask;
        public Task<int> GetDbVersionAsync() => Task.FromResult(0);
        public Task ImportDatabaseAsync(string sourcePath) => Task.CompletedTask;
    }
}
