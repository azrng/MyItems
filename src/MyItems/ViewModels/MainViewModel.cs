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

    private List<ItemDisplayDto> _sourceItems = [];
    private List<ItemDisplayDto> _allItems = [];
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
        RemoveDeletedItem(item.ItemId);
    }

    [RelayCommand]
    private async Task DeleteWithConfirmAsync(Guid itemId)
    {
        var item = _allItems.FirstOrDefault(i => i.ItemId == itemId);
        var name = item?.ItemName ?? "这个物品";
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{name}」吗？", "删除", "取消");
        if (!confirm) return;

        await _dataService.DeleteItemAsync(itemId);
        RemoveDeletedItem(itemId);
    }

    [RelayCommand]
    private async Task ViewItemDetailAsync(Guid itemId)
    {
        await Shell.Current.GoToAsync($"itemdetail?itemId={itemId}");
    }

    public async Task DeleteItemByIdAsync(Guid itemId)
    {
        await _dataService.DeleteItemAsync(itemId);
        RemoveDeletedItem(itemId);
    }

    [RelayCommand]
    private void LoadMore()
    {
        if (IsLoadingMore || !HasMoreItems) return;
        _ = LoadMoreAsync();
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
            ApplyFiltersAndResetPage();
        }
        catch (TaskCanceledException) { }
    }

    private async Task LoadDataAsync()
    {
        try
        {
            var snapshot = await _itemQueryCache.GetSnapshotAsync();
            _sourceItems = snapshot.Items;
            ApplyFiltersAndResetPage();
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

    private void ApplyFiltersAndResetPage()
    {
        var filtered = _sourceItems
            .OrderByDescending(i => i.PurchaseDate)
            .ToList();

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            filtered = filtered
                .Where(i => i.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase))
                .ToList();
        }

        _allItems = filtered;
        _loadedCount = 0;
        RecentItems.Clear();

        AppendPage();
    }

    private void RemoveDeletedItem(Guid itemId)
    {
        _itemQueryCache.Invalidate();
        _sourceItems.RemoveAll(i => i.ItemId == itemId);
        ApplyFiltersAndResetPage();
    }

    private void ResetLoadedData()
    {
        _sourceItems = [];
        _allItems = [];
        _loadedCount = 0;
        RecentItems.Clear();
        HasMoreItems = false;
    }

    private async Task LoadMoreAsync()
    {
        try
        {
            IsLoadingMore = true;
            await Task.Delay(100);
            AppendPage();
        }
        finally
        {
            IsLoadingMore = false;
        }
    }

    private void AppendPage()
    {
        var next = _allItems.Skip(_loadedCount).Take(PageSize).ToList();
        foreach (var item in next)
            RecentItems.Add(item);

        _loadedCount += next.Count;
        HasMoreItems = _loadedCount < _allItems.Count;
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
