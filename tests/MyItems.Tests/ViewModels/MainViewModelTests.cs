using MyItems.Enums;
using MyItems.Models.DTOs;
using MyItems.Services;
using MyItems.ViewModels;
using Xunit;

namespace MyItems.Tests.ViewModels;

public sealed class MainViewModelTests
{
    [Fact]
    public async Task RefreshCommand_ClearsLoadingAndRefreshing_WhenLoadFails()
    {
        var cache = new FakeItemQueryCache
        {
            LoadSnapshot = () => throw new InvalidOperationException("database busy"),
        };
        var viewModel = new MainViewModel(cache, new NoopDataService());

        await viewModel.RefreshCommand.ExecuteAsync(null);

        Assert.False(viewModel.IsLoading);
        Assert.False(viewModel.IsRefreshing);
        Assert.True(viewModel.IsEmpty);
    }

    [Fact]
    public async Task RefreshCommand_LoadsFirstPageFromDataService()
    {
        var cache = new FakeItemQueryCache
        {
            LoadSnapshot = () => new ItemQuerySnapshot([CreateItem("牙膏")], 10, 1, 1),
        };
        var dataService = new PagedDataService
        {
            LoadPage = options => new PagedItemDisplayResult([CreateItem("牙膏")], 2),
        };
        var viewModel = new MainViewModel(cache, dataService);

        await viewModel.RefreshCommand.ExecuteAsync(null);

        Assert.Equal(0, cache.LoadCount);
        var request = Assert.Single(dataService.PageRequests);
        Assert.Equal(0, request.Offset);
        Assert.Equal(20, request.Limit);
        var item = Assert.Single(viewModel.RecentItems);
        Assert.Equal("牙膏", item.ItemName);
        Assert.True(viewModel.HasMoreItems);
    }

    [Fact]
    public async Task LoadMoreCommand_LoadsNextPageFromDataService()
    {
        var dataService = new PagedDataService
        {
            LoadPage = options => new PagedItemDisplayResult(
                [CreateItem(options.Offset == 0 ? "第一页" : "第二页")],
                2),
        };
        var viewModel = new MainViewModel(new FakeItemQueryCache(), dataService);

        await viewModel.RefreshCommand.ExecuteAsync(null);
        await viewModel.LoadMoreCommand.ExecuteAsync(null);

        Assert.Equal([0, 1], dataService.PageRequests.Select(r => r.Offset).ToArray());
        Assert.Equal(["第一页", "第二页"], viewModel.RecentItems.Select(i => i.ItemName).ToArray());
    }

    private static ItemDisplayDto CreateItem(string name)
    {
        return new ItemDisplayDto
        {
            ItemId = Guid.NewGuid(),
            ItemName = name,
            Quantity = 1,
            PurchaseDate = DateTime.Today,
            ExpiryStatus = ExpiryStatus.Safe,
        };
    }

    private sealed class PagedDataService : NoopDataService
    {
        public Func<ItemQueryOptions, PagedItemDisplayResult>? LoadPage { get; init; }
        public List<ItemQueryOptions> PageRequests { get; } = [];

        public override Task<PagedItemDisplayResult> GetItemDisplayPageAsync(ItemQueryOptions options)
        {
            PageRequests.Add(options);
            return Task.FromResult(LoadPage?.Invoke(options) ?? new PagedItemDisplayResult([], 0));
        }
    }
}
