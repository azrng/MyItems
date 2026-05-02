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
    private const int PageSize = 10;

    private List<ItemDisplayDto> _allItems = [];
    private int _loadedCount;

    public ObservableCollection<ItemDisplayDto> Items { get; } = [];
    public ObservableCollection<Category> Categories { get; } = [];

    [ObservableProperty]
    private Category selectedCategory = null!;

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private bool isLoadingMore;

    [ObservableProperty]
    private bool hasMoreItems;

    [ObservableProperty]
    private string searchText = string.Empty;

    [ObservableProperty]
    private string totalSpentText = string.Empty;

    [ObservableProperty]
    private string validCountText = string.Empty;

    [ObservableProperty]
    private string totalItemsText = string.Empty;

    [ObservableProperty]
    private bool isSettingsOpen;

    public bool IsEmpty => !IsLoading && Items.Count == 0 && _allItems.Count == 0;

    private CancellationTokenSource? _searchCts;

    public ItemLibraryViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = InitializeAsync();
    }

    [RelayCommand]
    private void ToggleSettings()
    {
        IsSettingsOpen = !IsSettingsOpen;
    }

    [RelayCommand]
    private void CloseSettings()
    {
        IsSettingsOpen = false;
    }

    [RelayCommand]
    private async Task ViewItemDetailAsync(Guid itemId)
    {
        await Shell.Current.GoToAsync($"itemdetail?itemId={itemId}");
    }

    [RelayCommand]
    private async Task GoToCategoryAsync()
    {
        IsSettingsOpen = false;
        await Shell.Current.GoToAsync("category");
    }

    [RelayCommand]
    private async Task GoToStorageAsync()
    {
        IsSettingsOpen = false;
        await Shell.Current.GoToAsync("storage");
    }

    [RelayCommand]
    private async Task GoToAboutAsync()
    {
        IsSettingsOpen = false;
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
    private async Task SeedTestDataAsync()
    {
        var confirm = await Shell.Current.DisplayAlertAsync("初始化测试数据", "将插入约 200 个测试物品，确认继续？", "确定", "取消");
        if (!confirm) return;

        await _dataService.SeedSampleDataAsync();
        await InitializeAsync();
    }

    [RelayCommand]
    private void Refresh()
    {
        _ = LoadDataAsync();
    }

    [RelayCommand]
    private void LoadMore()
    {
        if (IsLoadingMore || !HasMoreItems) return;
        _ = LoadMoreAsync();
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
        ValidCountText = $"{stats.ValidItems} 件有效";
        TotalItemsText = $"共 {stats.TotalItems} 件";

        var items = (await _dataService.GetItemDisplayDtosAsync()).AsEnumerable();

        if (SelectedCategory is { Id: var categoryId } && categoryId != Guid.Empty)
            items = items.Where(i => i.CategoryId == categoryId);

        if (!string.IsNullOrWhiteSpace(SearchText))
            items = items.Where(i => i.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase));

        _allItems = items.OrderBy(i => i.ItemName).ToList();
        _loadedCount = 0;
        Items.Clear();

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
            Items.Add(item);

        _loadedCount += next.Count;
        HasMoreItems = _loadedCount < _allItems.Count;
        OnPropertyChanged(nameof(IsEmpty));
    }
}
