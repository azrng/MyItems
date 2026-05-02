using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly IDataService _dataService;
    private const int PageSize = 20;

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

    public MainViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = LoadDataAsync();
    }

    [RelayCommand]
    private async Task RefreshAsync()
    {
        IsRefreshing = true;
        await LoadDataAsync();
        IsRefreshing = false;
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
        await LoadDataAsync();
    }

    [RelayCommand]
    private async Task ViewItemDetailAsync(Guid itemId)
    {
        await Shell.Current.GoToAsync($"itemdetail?itemId={itemId}");
    }

    public async Task DeleteItemByIdAsync(Guid itemId)
    {
        await _dataService.DeleteItemAsync(itemId);
        await LoadDataAsync();
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
            await LoadDataAsync();
        }
        catch (TaskCanceledException) { }
    }

    private async Task LoadDataAsync()
    {
        var items = await _dataService.GetItemDisplayDtosAsync();

        var filtered = items
            .OrderByDescending(i => i.CreatedAt)
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
        IsLoading = false;
    }

    private async Task LoadMoreAsync()
    {
        IsLoadingMore = true;
        await Task.Delay(100);
        AppendPage();
        IsLoadingMore = false;
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

    public bool IsEmpty => !IsLoading && RecentItems.Count == 0 && _allItems.Count == 0;
}
