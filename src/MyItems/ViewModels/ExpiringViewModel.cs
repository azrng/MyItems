using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Enums;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ExpiringViewModel : ObservableObject
{
    private readonly IDataService _dataService;

    public ObservableCollection<ItemDisplayDto> ExpiringItems { get; private set; } = [];
    public ObservableCollection<ItemDisplayDto> ExpiredItems { get; private set; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private bool isRefreshing;

    [ObservableProperty]
    private string searchText = string.Empty;

    private CancellationTokenSource? _searchCts;

    public ExpiringViewModel(IDataService dataService)
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
    private void Search()
    {
        _ = LoadDataAsync();
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

        var filtered = items.Where(i => i.ExpiryStatus != ExpiryStatus.NoExpiry);

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            filtered = filtered.Where(i =>
                i.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
        }

        var list = filtered.OrderBy(i => i.ExpiryDate).ToList();

        UpdateCollection(ExpiringItems, list.Where(i => i.ExpiryStatus == ExpiryStatus.Expiring));
        UpdateCollection(ExpiredItems, list.Where(i => i.ExpiryStatus == ExpiryStatus.Expired));

        OnPropertyChanged(nameof(ExpiringItems));
        OnPropertyChanged(nameof(ExpiredItems));
        OnPropertyChanged(nameof(HasExpiring));
        OnPropertyChanged(nameof(HasExpired));
        OnPropertyChanged(nameof(IsEmpty));
        IsLoading = false;
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
}
