using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ItemLibraryViewModel : ObservableObject
{
    private readonly IDataService _dataService;

    public ObservableCollection<ItemDisplayDto> Items { get; private set; } = [];
    public ObservableCollection<Category> Categories { get; } = [];

    [ObservableProperty]
    private Category selectedCategory = null!;

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

    private CancellationTokenSource? _searchCts;

    public ItemLibraryViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = InitializeAsync();
    }

    [RelayCommand]
    private async Task ViewItemDetailAsync(Guid itemId)
    {
        await Shell.Current.GoToAsync($"itemdetail?itemId={itemId}");
    }

    [RelayCommand]
    private async Task GoToCategoryAsync()
    {
        await Shell.Current.GoToAsync("category");
    }

    [RelayCommand]
    private async Task GoToAboutAsync()
    {
        await Shell.Current.GoToAsync("AboutPage");
    }

    [RelayCommand]
    private async Task ExportExcelAsync()
    {
        try
        {
            var path = await _dataService.ExportToExcelAsync();
            await Share.Default.RequestAsync(new ShareFileRequest
            {
                Title = "导出物品数据",
                File = new ShareFile(path)
            });
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("导出失败", ex.Message, "确定");
        }
    }

    [RelayCommand]
    private void Refresh()
    {
        IsLoading = true;
        _ = LoadDataAsync();
    }

    partial void OnSelectedCategoryChanged(Category value)
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

    private async Task InitializeAsync()
    {
        await LoadCategoriesAsync();
        await LoadDataAsync();
    }

    private async Task LoadCategoriesAsync()
    {
        Categories.Clear();
        Categories.Add(new Category { Id = Guid.Empty, Name = "全部" });
        var categories = await _dataService.GetCategoriesAsync();
        foreach (var cat in categories.Where(c => c.IsActive).OrderBy(c => c.SortOrder))
            Categories.Add(cat);
        SelectedCategory = Categories[0];
    }

    private async Task LoadDataAsync()
    {
        var stats = await _dataService.GetStatisticsAsync();
        TotalSpentText = $"¥{stats.TotalSpent:F1}";
        ValidCountText = $"{stats.ValidBatches} 件有效";
        TotalBatchesText = $"共 {stats.TotalBatches} 件";

        var items = (await _dataService.GetItemDisplayDtosAsync()).AsEnumerable();

        if (SelectedCategory is { Id: var categoryId } && categoryId != Guid.Empty)
            items = items.Where(i => i.CategoryId == categoryId);

        if (!string.IsNullOrWhiteSpace(SearchText))
            items = items.Where(i => i.Name.Contains(SearchText, StringComparison.OrdinalIgnoreCase));

        Items = new ObservableCollection<ItemDisplayDto>(items.OrderBy(i => i.Name));
        OnPropertyChanged(nameof(Items));
        IsLoading = false;
    }
}
