using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Enums;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class MainViewModel : ObservableObject
{
    public ObservableCollection<ExpiryGroupDto> ExpiryGroups { get; private set; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string searchText = string.Empty;

    private CancellationTokenSource? _searchCts;

    public MainViewModel()
    {
        LoadData();
    }

    [RelayCommand]
    private void Refresh()
    {
        IsLoading = true;
        LoadData();
    }

    [RelayCommand]
    private void ToggleGroup(ExpiryGroupDto group)
    {
        group.IsExpanded = !group.IsExpanded;
    }

    [RelayCommand]
    private void Search()
    {
        LoadData();
    }

    [RelayCommand]
    private async Task GoToAddAsync()
    {
        await Shell.Current.GoToAsync("add");
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
            LoadData();
        }
        catch (TaskCanceledException) { }
    }

    private void LoadData()
    {
        var groups = MockDataService.GetExpiryGroups()
            .Where(g => g.Status is ExpiryStatus.Expired or ExpiryStatus.Expiring)
            .ToList();

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            groups = groups.Select(g => new ExpiryGroupDto
            {
                Status = g.Status,
                Title = g.Title,
                StatusIcon = g.StatusIcon,
                IsExpanded = true,
                Batches = g.Batches.Where(b =>
                    b.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase)).ToList(),
            }).Where(g => g.Batches.Count > 0).ToList();
        }

        ExpiryGroups = new ObservableCollection<ExpiryGroupDto>(groups);
        OnPropertyChanged(nameof(ExpiryGroups));
        IsLoading = false;
    }
}
