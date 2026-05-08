using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Enums;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ExpiringViewModel : ObservableObject
{
    private readonly IItemQueryCache _itemQueryCache;
    private readonly IDataService _dataService;
    private List<ItemDisplayDto> _sourceItems = [];

    public ObservableCollection<ItemDisplayDto> ExpiringItems { get; private set; } = [];
    public ObservableCollection<ItemDisplayDto> ExpiredItems { get; private set; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private bool isRefreshing;

    [ObservableProperty]
    private string searchText = string.Empty;

    private CancellationTokenSource? _searchCts;

    public ExpiringViewModel(IItemQueryCache itemQueryCache, IDataService dataService)
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
    private async Task DeleteItemAsync(Guid itemId)
    {
        var item = ExpiringItems.Concat(ExpiredItems).FirstOrDefault(i => i.ItemId == itemId);
        var name = item?.ItemName ?? "这个物品";
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{name}」吗？", "删除", "取消");
        if (!confirm) return;

        await _dataService.DeleteItemAsync(itemId);
        _itemQueryCache.Invalidate();
        _sourceItems.RemoveAll(i => i.ItemId == itemId);
        ApplyFilters();
    }

    [RelayCommand]
    private void Search()
    {
        ApplyFilters();
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
            ApplyFilters();
        }
        catch (TaskCanceledException) { }
    }

    private async Task LoadDataAsync()
    {
        try
        {
            var snapshot = await _itemQueryCache.GetSnapshotAsync();
            _sourceItems = snapshot.Items;
            ApplyFilters();
        }
        catch (Exception ex)
        {
            _sourceItems = [];
            ExpiringItems.Clear();
            ExpiredItems.Clear();
            _ = ShowLoadErrorAsync(ex);
        }
        finally
        {
            IsLoading = false;
            RefreshStateProperties();
        }
    }

    private void ApplyFilters()
    {
        var filtered = _sourceItems.Where(i => i.ExpiryStatus != ExpiryStatus.NoExpiry);

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            filtered = filtered.Where(i =>
                i.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
        }

        var list = filtered.OrderBy(i => i.ExpiryDate).ToList();

        UpdateCollection(ExpiringItems, list.Where(i => i.ExpiryStatus == ExpiryStatus.Expiring));
        UpdateCollection(ExpiredItems, list.Where(i => i.ExpiryStatus == ExpiryStatus.Expired));

        RefreshStateProperties();
    }

    private void RefreshStateProperties()
    {
        OnPropertyChanged(nameof(ExpiringItems));
        OnPropertyChanged(nameof(ExpiredItems));
        OnPropertyChanged(nameof(HasExpiring));
        OnPropertyChanged(nameof(HasExpired));
        OnPropertyChanged(nameof(IsEmpty));
    }

    public bool HasExpiring => ExpiringItems.Count > 0;
    public bool HasExpired => ExpiredItems.Count > 0;
    public bool IsEmpty => !IsLoading && !HasExpiring && !HasExpired;

    private static void UpdateCollection(ObservableCollection<ItemDisplayDto> collection, IEnumerable<ItemDisplayDto> newItems)
    {
        var newList = newItems.ToList();
        for (var i = 0; i < newList.Count; i++)
        {
            if (i < collection.Count)
                collection[i] = newList[i];
            else
                collection.Add(newList[i]);
        }
        while (collection.Count > newList.Count)
            collection.RemoveAt(collection.Count - 1);
    }

    private static Task ShowLoadErrorAsync(Exception ex)
    {
        return MainThread.InvokeOnMainThreadAsync(async () =>
        {
            if (Shell.Current is not null)
                await Shell.Current.DisplayAlertAsync("加载失败", $"临期数据加载失败：{ex.Message}", "确定");
        });
    }
}
