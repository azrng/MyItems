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
    public async Task RefreshCommand_UsesItemQueryCacheSnapshot()
    {
        var cache = new FakeItemQueryCache
        {
            LoadSnapshot = () => new ItemQuerySnapshot([CreateItem("牙膏")], 10, 1, 1),
        };
        var viewModel = new MainViewModel(cache, new NoopDataService());

        await viewModel.RefreshCommand.ExecuteAsync(null);

        Assert.Equal(1, cache.LoadCount);
        var item = Assert.Single(viewModel.RecentItems);
        Assert.Equal("牙膏", item.ItemName);
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
}
