using MyItems.Enums;
using MyItems.Models.DTOs;
using MyItems.Services;
using MyItems.ViewModels;
using Xunit;

namespace MyItems.Tests.ViewModels;

public sealed class ExpiringViewModelTests
{
    [Fact]
    public async Task RefreshCommand_ClearsLoadingAndRefreshing_WhenLoadFails()
    {
        var cache = new FakeItemQueryCache
        {
            LoadSnapshot = () => throw new InvalidOperationException("database busy"),
        };
        var viewModel = new ExpiringViewModel(cache, new NoopDataService());

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
            LoadSnapshot = () => new ItemQuerySnapshot([CreateItem("牛奶", ExpiryStatus.Expiring)], 10, 1, 1),
        };
        var viewModel = new ExpiringViewModel(cache, new NoopDataService());

        await viewModel.RefreshCommand.ExecuteAsync(null);

        Assert.Equal(1, cache.LoadCount);
        var item = Assert.Single(viewModel.ExpiringItems);
        Assert.Equal("牛奶", item.ItemName);
    }

    private static ItemDisplayDto CreateItem(string name, ExpiryStatus status)
    {
        return new ItemDisplayDto
        {
            ItemId = Guid.NewGuid(),
            ItemName = name,
            Quantity = 1,
            ExpiryDate = DateTime.Today.AddDays(1),
            ExpiryStatus = status,
        };
    }
}
