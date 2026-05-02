using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ItemLibraryViewModel : ObservableObject
{
    public ObservableCollection<ItemDisplayDto> Items { get; } = [];
    public ObservableCollection<Category> Categories { get; } = [];

    [ObservableProperty]
    private Category? selectedCategory;

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

    public ItemLibraryViewModel()
    {
        LoadCategories();
        LoadData();
    }

    [RelayCommand]
    private async Task ViewItemDetailAsync(Guid itemId)
    {
        await Shell.Current.GoToAsync($"itemdetail?itemId={itemId}");
    }

    [RelayCommand]
    private void Refresh()
    {
        IsLoading = true;
        LoadData();
        IsLoading = false;
    }

    partial void OnSelectedCategoryChanged(Category? value)
    {
        LoadData();
    }

    partial void OnSearchTextChanged(string value)
    {
        LoadData();
    }

    private void LoadCategories()
    {
        Categories.Clear();
        Categories.Add(null!);
        foreach (var cat in MockDataService.GetPresetCategories().OrderBy(c => c.SortOrder))
            Categories.Add(cat);
        SelectedCategory = null;
    }

    private void LoadData()
    {
        var stats = MockDataService.GetStatistics();
        TotalSpentText = $"¥{stats.TotalSpent:F1}";
        ValidCountText = $"{stats.ValidBatches} 件有效";
        TotalBatchesText = $"共 {stats.TotalBatches} 件";

        var items = MockDataService.GetItemDisplayDtos().AsEnumerable();

        if (SelectedCategory is not null)
            items = items.Where(i => i.CategoryId == SelectedCategory.Id);

        if (!string.IsNullOrWhiteSpace(SearchText))
            items = items.Where(i => i.Name.Contains(SearchText, StringComparison.OrdinalIgnoreCase));

        Items.Clear();
        foreach (var item in items.OrderBy(i => i.Name))
            Items.Add(item);

        IsLoading = false;
    }
}
