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

    public ObservableCollection<BatchDisplayDto> ExpiringItems { get; private set; } = [];
    public ObservableCollection<BatchDisplayDto> ExpiredItems { get; private set; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string searchText = string.Empty;

    private CancellationTokenSource? _searchCts;

    public ExpiringViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = LoadDataAsync();
    }

    [RelayCommand]
    private void Refresh()
    {
        IsLoading = true;
        _ = LoadDataAsync();
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
        var batches = await _dataService.GetBatchDisplayDtosAsync();

        // Filter out no-expiry, apply search
        var filtered = batches.Where(b => b.ExpiryStatus != ExpiryStatus.NoExpiry);

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            filtered = filtered.Where(b =>
                b.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase));
        }

        var list = filtered.OrderBy(b => b.ExpiryDate).ToList();

        ExpiringItems = new ObservableCollection<BatchDisplayDto>(
            list.Where(b => b.ExpiryStatus == ExpiryStatus.Expiring));
        ExpiredItems = new ObservableCollection<BatchDisplayDto>(
            list.Where(b => b.ExpiryStatus == ExpiryStatus.Expired));

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
}
