using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly IDataService _dataService;
    private const int PageSize = 10;

    private List<BatchDisplayDto> _allItems = [];
    private int _loadedCount;

    public ObservableCollection<BatchDisplayDto> RecentItems { get; } = [];

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
    private async Task DeleteBatchAsync(BatchDisplayDto batch)
    {
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{batch.ItemName}」吗？", "删除", "取消");
        if (!confirm) return;

        await _dataService.DeleteBatchAsync(batch.BatchId);
        await LoadDataAsync();
    }

    [RelayCommand]
    private async Task ViewItemDetailAsync(Guid itemId)
    {
        await Shell.Current.GoToAsync($"itemdetail?itemId={itemId}");
    }

    public async Task DeleteBatchByIdAsync(Guid batchId)
    {
        await _dataService.DeleteBatchAsync(batchId);
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
        var cutoff = DateTime.Now.AddDays(-7);
        var batches = await _dataService.GetBatchDisplayDtosAsync();

        var filtered = batches
            .Where(b => (b.PurchaseDate ?? DateTime.MinValue) >= cutoff)
            .OrderByDescending(b => b.PurchaseDate)
            .ToList();

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            filtered = filtered
                .Where(b => b.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase))
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
        await Task.Delay(100); // brief delay for smoother UX
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
