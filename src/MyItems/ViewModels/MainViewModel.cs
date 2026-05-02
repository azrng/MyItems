using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Enums;
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

    [RelayCommand]
    private async Task GoToAddAsync()
    {
        await Shell.Current.GoToAsync("//add");
    }

    partial void OnSearchTextChanged(string value)
    {
        LoadData();
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

        ExpiryGroups.Clear();
        foreach (var group in groups)
            ExpiryGroups.Add(group);

        IsLoading = false;
    }
}
