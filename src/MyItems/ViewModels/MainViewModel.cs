using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class MainViewModel : ObservableObject
{
    public ObservableCollection<ExpiryGroupDto> ExpiryGroups { get; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string searchText = string.Empty;

    [ObservableProperty]
    private string totalSpentText = string.Empty;

    [ObservableProperty]
    private string validCountText = string.Empty;

    [ObservableProperty]
    private string totalBatchesText = string.Empty;

    public MainViewModel()
    {
        LoadData();
    }

    [RelayCommand]
    private void Refresh()
    {
        IsLoading = true;
        LoadData();
        IsLoading = false;
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

    partial void OnSearchTextChanged(string value)
    {
        LoadData();
    }

    private void LoadData()
    {
        var groups = MockDataService.GetExpiryGroups();
        var stats = MockDataService.GetStatistics();

        TotalSpentText = $"¥{stats.TotalSpent:F1}";
        ValidCountText = $"{stats.ValidBatches} 件有效";
        TotalBatchesText = $"共 {stats.TotalBatches} 件";

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

        ExpiryGroups.Clear();
        foreach (var group in groups)
            ExpiryGroups.Add(group);

        IsLoading = false;
    }
}
