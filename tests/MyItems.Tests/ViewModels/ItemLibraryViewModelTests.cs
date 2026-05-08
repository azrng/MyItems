using MyItems.Enums;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;
using MyItems.ViewModels;
using Xunit;

namespace MyItems.Tests.ViewModels;

public sealed class ItemLibraryViewModelTests
{
    [Fact]
    public async Task InitializeCommand_ClearsLoadingState_WhenItemLoadFails()
    {
        Shell.Current = new Shell();
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = Guid.NewGuid(), Name = "食品", IsActive = true }],
            LoadItems = () => throw new InvalidOperationException("database busy"),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        await viewModel.InitializeCommand.ExecuteAsync(null);

        Assert.False(viewModel.IsLoading);
        Assert.Empty(viewModel.Items);
        Assert.True(viewModel.IsEmpty);
    }

    [Fact]
    public async Task InitializeCommand_ClearsLoadingState_WhenCategoryLoadFailsBeforeErrorDialogCompletes()
    {
        Shell.Current = new HangingAlertShell();
        var dataService = new FakeDataService
        {
            LoadCategories = () => throw new InvalidOperationException("category database busy"),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        var initializeTask = viewModel.InitializeCommand.ExecuteAsync(null);
        var completed = await Task.WhenAny(initializeTask, Task.Delay(200));

        Assert.Same(initializeTask, completed);
        Assert.False(viewModel.IsLoading);
        Assert.Empty(viewModel.Items);
        Assert.True(viewModel.IsEmpty);
        Shell.Current = new Shell();
    }

    [Fact]
    public async Task InitializeCommand_ClearsLoadingState_BeforeErrorDialogCompletes()
    {
        Shell.Current = new HangingAlertShell();
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = Guid.NewGuid(), Name = "食品", IsActive = true }],
            LoadItems = () => throw new InvalidOperationException("database busy"),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        var initializeTask = viewModel.InitializeCommand.ExecuteAsync(null);
        var completed = await Task.WhenAny(initializeTask, Task.Delay(200));

        Assert.Same(initializeTask, completed);
        Assert.False(viewModel.IsLoading);
        Assert.Empty(viewModel.Items);
        Assert.True(viewModel.IsEmpty);
        Shell.Current = new Shell();
    }

    [Fact]
    public async Task RefreshCommand_DoesNotKeepLoading_WhenConcurrentRefreshesOverlap()
    {
        Shell.Current = new Shell();
        var releaseLoad = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = Guid.NewGuid(), Name = "食品", IsActive = true }],
            LoadItemsAsync = async () =>
            {
                await releaseLoad.Task;
                return CreateResult(CreateItem("牙膏"));
            },
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        var first = viewModel.InitializeCommand.ExecuteAsync(null);
        var second = viewModel.RefreshCommand.ExecuteAsync(null);
        releaseLoad.SetResult();
        await Task.WhenAll(first, second);

        Assert.False(viewModel.IsLoading);
        Assert.Single(viewModel.Items);
    }

    [Fact]
    public async Task IsEmpty_IsTrue_WhenFilterLeavesNoVisibleItems()
    {
        Shell.Current = new Shell();
        var categoryId = Guid.NewGuid();
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = categoryId, Name = "日用", IsActive = true }],
            LoadItems = () => CreateResult(CreateItem("牙膏", categoryId)),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        await viewModel.InitializeCommand.ExecuteAsync(null);
        viewModel.SearchText = "不存在";
        await Task.Delay(400);

        Assert.Empty(viewModel.Items);
        Assert.True(viewModel.IsEmpty);
    }

    [Fact]
    public async Task SelectingCategory_ReloadsFirstPageWithCategoryFilter()
    {
        Shell.Current = new Shell();
        var targetCategoryId = Guid.NewGuid();
        var otherCategoryId = Guid.NewGuid();
        var dataService = new FakeDataService
        {
            Categories =
            [
                new Category { Id = targetCategoryId, Name = "日用", SortOrder = 1, IsActive = true },
                new Category { Id = otherCategoryId, Name = "食品", SortOrder = 2, IsActive = true },
            ],
            LoadPage = options => new PagedItemDisplayResult(
                options.CategoryId == targetCategoryId ? [CreateItem("牙膏", targetCategoryId)] : [CreateItem("面包", otherCategoryId)],
                1),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        await viewModel.InitializeCommand.ExecuteAsync(null);
        viewModel.Categories[1].SelectCommand.Execute(null);
        await dataService.WaitForPageRequestsAsync(2);

        Assert.Equal(2, dataService.PageRequests.Count);
        Assert.Equal(targetCategoryId, dataService.PageRequests[1].CategoryId);
        Assert.Equal(0, dataService.PageRequests[1].Offset);
        var item = Assert.Single(viewModel.Items);
        Assert.Equal("牙膏", item.ItemName);
    }

    [Fact]
    public async Task ApplySearchFilter_ReloadsFirstPageWithAdvancedFilter()
    {
        Shell.Current = new Shell();
        var categoryId = Guid.NewGuid();
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = categoryId, Name = "日用", SortOrder = 1, IsActive = true }],
            LoadPage = options => new PagedItemDisplayResult(
                options.AdvancedSearchFilter?.Keyword == "牙" ? [CreateItem("牙膏", categoryId)] : [CreateItem("面包", categoryId)],
                1),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        await viewModel.InitializeCommand.ExecuteAsync(null);
        await viewModel.ApplySearchFilter(new SearchFilter { Keyword = "牙" });

        Assert.Equal(2, dataService.PageRequests.Count);
        Assert.Equal("牙", dataService.PageRequests[1].AdvancedSearchFilter?.Keyword);
        var item = Assert.Single(viewModel.Items);
        Assert.Equal("牙膏", item.ItemName);
    }

    [Fact]
    public async Task DeleteItemCommand_RemovesDeletedItemFromCachedItems()
    {
        Shell.Current = new Shell();
        var deletedItem = CreateItem("牙膏");
        var remainingItem = CreateItem("面包");
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = Guid.NewGuid(), Name = "日用", IsActive = true }],
            LoadItems = () => CreateResult(deletedItem, remainingItem),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        await viewModel.InitializeCommand.ExecuteAsync(null);
        await viewModel.DeleteItemCommand.ExecuteAsync(deletedItem.ItemId);

        Assert.DoesNotContain(viewModel.Items, item => item.ItemId == deletedItem.ItemId);
        Assert.Contains(viewModel.Items, item => item.ItemId == remainingItem.ItemId);
    }

    [Fact]
    public async Task InitializeCommand_LoadsStatisticsAndItemsFromPagedQuery()
    {
        Shell.Current = new Shell();
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = Guid.NewGuid(), Name = "日用", IsActive = true }],
            LoadPage = _ => new PagedItemDisplayResult([CreateItem("分页物品")], 1),
        };
        var cache = new FakeItemQueryCache();
        var viewModel = new ItemLibraryViewModel(dataService, cache);

        await viewModel.InitializeCommand.ExecuteAsync(null);

        Assert.Equal(0, cache.LoadCount);
        Assert.Equal(1, dataService.StatisticsLoadCount);
        var request = Assert.Single(dataService.PageRequests);
        Assert.Equal(0, request.Offset);
        Assert.Equal(10, request.Limit);
        var visibleItem = Assert.Single(viewModel.Items);
        Assert.Equal("分页物品", visibleItem.ItemName);
        Assert.Equal("¥10.0", viewModel.TotalSpentText);
    }

    [Fact]
    public async Task LoadMoreCommand_LoadsNextPageFromDataService()
    {
        Shell.Current = new Shell();
        var categoryId = Guid.NewGuid();
        var dataService = new FakeDataService
        {
            Categories = [new Category { Id = categoryId, Name = "日用", IsActive = true }],
            LoadPage = options => new PagedItemDisplayResult(
                [CreateItem(options.Offset == 0 ? "第一页" : "第二页", categoryId)],
                2),
        };
        var viewModel = new ItemLibraryViewModel(dataService);

        await viewModel.InitializeCommand.ExecuteAsync(null);
        await viewModel.LoadMoreCommand.ExecuteAsync(null);

        Assert.Equal([0, 1], dataService.PageRequests.Select(r => r.Offset).ToArray());
        Assert.Equal(["第一页", "第二页"], viewModel.Items.Select(i => i.ItemName).ToArray());
    }

    private static ItemDisplayDto CreateItem(string name, Guid? categoryId = null)
    {
        return new ItemDisplayDto
        {
            ItemId = Guid.NewGuid(),
            ItemName = name,
            CategoryId = categoryId ?? Guid.NewGuid(),
            PurchaseDate = DateTime.Today,
            Quantity = 1,
            ExpiryStatus = ExpiryStatus.Safe,
        };
    }

    private static (List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems) CreateResult(params ItemDisplayDto[] items)
    {
        return (items.ToList(), 10, items.Length, items.Length);
    }

    private sealed class FakeDataService : IDataService
    {
        public List<Category> Categories { get; init; } = [];
        public Func<List<Category>>? LoadCategories { get; init; }
        public Func<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)>? LoadItems { get; init; }
        public Func<Task<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)>>? LoadItemsAsync { get; init; }
        public Func<ItemQueryOptions, PagedItemDisplayResult>? LoadPage { get; init; }
        public int ItemsLoadCount { get; private set; }
        public int StatisticsLoadCount { get; private set; }
        public List<ItemQueryOptions> PageRequests { get; } = [];
        private readonly HashSet<Guid> _deletedItemIds = [];

        public Task InitializeAsync() => Task.CompletedTask;
        public Task<List<Category>> GetCategoriesAsync() => Task.FromResult(LoadCategories?.Invoke() ?? Categories);
        public Task<int> SaveCategoryAsync(Category category) => Task.FromResult(1);
        public Task<int> DeleteCategoryAsync(Category category) => Task.FromResult(1);
        public Task<bool> CategoryHasItemsAsync(Guid categoryId) => Task.FromResult(false);
        public Task<List<Item>> GetItemsAsync() => Task.FromResult(new List<Item>());
        public Task<Item?> GetItemByIdAsync(Guid itemId) => Task.FromResult<Item?>(null);
        public Task<Guid> SaveItemAsync(Item item) => Task.FromResult(item.Id);
        public Task<int> DeleteItemAsync(Guid itemId)
        {
            _deletedItemIds.Add(itemId);
            return Task.FromResult(1);
        }
        public Task<ItemDisplayDto?> GetItemDisplayDtoByIdAsync(Guid itemId) => Task.FromResult<ItemDisplayDto?>(null);
        public Task<List<ItemDisplayDto>> GetItemDisplayDtosAsync() => Task.FromResult(new List<ItemDisplayDto>());
        public Task<List<ExpiryGroupDto>> GetExpiryGroupsAsync() => Task.FromResult(new List<ExpiryGroupDto>());
        public Task<List<CategoryDto>> GetCategoryDtosAsync() => Task.FromResult(new List<CategoryDto>());
        public Task<(decimal TotalSpent, int TotalItems, int ValidItems)> GetStatisticsAsync()
        {
            StatisticsLoadCount++;
            return Task.FromResult((10m, 1, 1));
        }

        public Task<(List<ItemDisplayDto> Items, decimal TotalSpent, int TotalItems, int ValidItems)> GetItemsWithStatisticsAsync()
        {
            ItemsLoadCount++;
            if (LoadItemsAsync is not null)
                return LoadItemsAsync();

            if (LoadItems is not null)
                return Task.FromResult(LoadItems());

            return Task.FromResult(CreateResult());
        }

        public async Task<PagedItemDisplayResult> GetItemDisplayPageAsync(ItemQueryOptions options)
        {
            PageRequests.Add(options);
            if (LoadPage is not null)
                return LoadPage(options);

            var result = LoadItemsAsync is not null
                ? await LoadItemsAsync()
                : LoadItems?.Invoke() ?? CreateResult();
            var filtered = result.Items
                .Where(item => !_deletedItemIds.Contains(item.ItemId));

            if (options.CategoryId is { } categoryId)
                filtered = filtered.Where(item => item.CategoryId == categoryId);

            if (!string.IsNullOrWhiteSpace(options.SearchText))
                filtered = filtered.Where(item => item.ItemName.Contains(options.SearchText, StringComparison.OrdinalIgnoreCase));

            var matching = filtered.ToList();
            var items = matching
                .Skip(options.SafeOffset)
                .Take(options.SafeLimit)
                .ToList();
            return new PagedItemDisplayResult(items, matching.Count);
        }

        public async Task WaitForPageRequestsAsync(int count)
        {
            for (var i = 0; i < 20 && PageRequests.Count < count; i++)
                await Task.Delay(25);
        }

        public Task<string> ExportToCsvAsync() => Task.FromResult(string.Empty);
        public Task<(int SuccessCount, int FailureCount, List<string> Errors)> ImportFromCsvAsync(string filePath) => Task.FromResult((0, 0, new List<string>()));
        public Task SeedSampleDataAsync() => Task.CompletedTask;
        public Task ClearAllDataAsync() => Task.CompletedTask;
        public Task<int> GetDbVersionAsync() => Task.FromResult(0);
        public Task ImportDatabaseAsync(string sourcePath) => Task.CompletedTask;
    }

    private sealed class HangingAlertShell : Shell
    {
        public override Task DisplayAlertAsync(string title, string message, string cancel)
        {
            return new TaskCompletionSource().Task;
        }
    }
}
