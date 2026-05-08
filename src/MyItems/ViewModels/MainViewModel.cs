using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly IItemQueryCache _itemQueryCache;
    private readonly IDataService _dataService;
    private const int PageSize = 20;

    private int _loadedCount;

    public ObservableCollection<ItemDisplayDto> RecentItems { get; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private bool isLoadingMore;

    [ObservableProperty]
    private bool hasMoreItems;

    [ObservableProperty]
    private bool isRefreshing;

    [ObservableProperty]
    private string searchText = string.Empty;

    private CancellationTokenSource? _searchCts;

    public MainViewModel(IItemQueryCache itemQueryCache, IDataService dataService)
    {
        _itemQueryCache = itemQueryCache;
        _dataService = dataService;
    }

    [RelayCommand]
    private async Task RefreshAsync()
    {
        try
        {
            IsRefreshing = true;
            await LoadDataAsync();
        }
        finally
        {
            IsRefreshing = false;
        }
    }

    [RelayCommand]
    private async Task GoToAddAsync()
    {
        await Shell.Current.GoToAsync("add");
    }

    [RelayCommand]
    private async Task DeleteItemAsync(ItemDisplayDto item)
    {
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{item.ItemName}」吗？", "删除", "取消");
        if (!confirm) return;

        await _dataService.DeleteItemAsync(item.ItemId);
        await RefreshAfterDeleteAsync();
    }

    [RelayCommand]
    private async Task DeleteWithConfirmAsync(Guid itemId)
    {
        var item = RecentItems.FirstOrDefault(i => i.ItemId == itemId);
        var name = item?.ItemName ?? "这个物品";
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{name}」吗？", "删除", "取消");
        if (!confirm) return;

        await _dataService.DeleteItemAsync(itemId);
        await RefreshAfterDeleteAsync();
    }

    [RelayCommand]
    private async Task ViewItemDetailAsync(Guid itemId)
    {
        await Shell.Current.GoToAsync($"itemdetail?itemId={itemId}");
    }

    public async Task DeleteItemByIdAsync(Guid itemId)
    {
        await _dataService.DeleteItemAsync(itemId);
        await RefreshAfterDeleteAsync();
    }

    [RelayCommand]
    private async Task LoadMoreAsync()
    {
        if (IsLoadingMore || !HasMoreItems) return;

        try
        {
            IsLoadingMore = true;
            var result = await LoadPageAsync(_loadedCount);
            AppendPage(result, replace: false);
        }
        finally
        {
            IsLoadingMore = false;
        }
    }

    partial void OnSearchTextChanged(string value)
    {
        _searchCts?.Cancel();
        _searchCts = new CancellationTokenSource();
        _ = DebounceSearchAsync(_searchCts.Token);
    }

    private async Task DebounceSearchAsync(CancellationToken ct)
    {
        try
        {
            await Task.Delay(300, ct);
            await LoadDataAsync();
        }
        catch (TaskCanceledException) { }
    }

    private async Task LoadDataAsync()
    {
        try
        {
            var result = await LoadPageAsync(0);
            AppendPage(result, replace: true);
        }
        catch (Exception ex)
        {
            ResetLoadedData();
            _ = ShowLoadErrorAsync(ex);
        }
        finally
        {
            IsLoading = false;
            OnPropertyChanged(nameof(IsEmpty));
        }
    }

    private Task<PagedItemDisplayResult> LoadPageAsync(int offset)
    {
        var options = new ItemQueryOptions(
            Offset: offset,
            Limit: PageSize,
            SearchText: SearchText);
        return _dataService.GetItemDisplayPageAsync(options);
    }

    private async Task RefreshAfterDeleteAsync()
    {
        _itemQueryCache.Invalidate();
        await LoadDataAsync();
    }

    private void ResetLoadedData()
    {
        _loadedCount = 0;
        RecentItems.Clear();
        HasMoreItems = false;
    }

    private void AppendPage(PagedItemDisplayResult result, bool replace)
    {
        if (replace)
        {
            _loadedCount = 0;
            RecentItems.Clear();
        }

        foreach (var item in result.Items)
            RecentItems.Add(item);

        _loadedCount += result.Items.Count;
        HasMoreItems = _loadedCount < result.TotalCount;
        OnPropertyChanged(nameof(IsEmpty));
    }

    public bool IsEmpty => !IsLoading && RecentItems.Count == 0;

    private static Task ShowLoadErrorAsync(Exception ex)
    {
        return MainThread.InvokeOnMainThreadAsync(async () =>
        {
            if (Shell.Current is not null)
                await Shell.Current.DisplayAlertAsync("加载失败", $"首页数据加载失败：{ex.Message}", "确定");
        });
    }
}
