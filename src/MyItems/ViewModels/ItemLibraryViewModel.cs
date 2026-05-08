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

    private List<ItemDisplayDto> _sourceItems = [];
    private List<ItemDisplayDto> _allItems = [];
    private int _loadedCount;
    private readonly SemaphoreSlim _initializeLock = new(1, 1);
    private readonly SemaphoreSlim _loadLock = new(1, 1);
    private bool _isInitialized;
    private bool _suppressCategorySelectionLoad;

    public ObservableCollection<ItemDisplayDto> Items { get; } = [];
    public ObservableCollection<SelectableCategory> Categories { get; } = [];

    [ObservableProperty]
    private SelectableCategory selectedCategory = null!;

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

    [ObservableProperty]
    private SearchFilter? advancedSearchFilter;

    public bool IsEmpty => !IsLoading && Items.Count == 0;

    private CancellationTokenSource? _searchCts;

    public ItemLibraryViewModel(IDataService dataService)
    {
        _dataService = dataService;
    }

    [RelayCommand]
    private void ToggleSettings()
    {
        IsSettingsOpen = !IsSettingsOpen;
    }

    [RelayCommand]
    private async Task DeleteItemAsync(Guid itemId)
    {
        var item = _allItems.FirstOrDefault(i => i.ItemId == itemId);
        var name = item?.ItemName ?? "这个物品";
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{name}」吗？", "删除", "取消");
        if (!confirm) return;

        await _dataService.DeleteItemAsync(itemId);
        _sourceItems.RemoveAll(i => i.ItemId == itemId);
        RefreshStatisticsFromCache();
        ApplyFiltersAndResetPage();
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
        await Task.Yield();

        try
        {
            await Shell.Current.GoToAsync("category");
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("打开失败", $"无法打开分类管理：{ex.Message}", "确定");
        }
    }

    [RelayCommand]
    private async Task GoToStorageAsync()
    {
        IsSettingsOpen = false;
        await Task.Delay(100);
        await Shell.Current.GoToAsync("storage");
    }

    [RelayCommand]
    private async Task GoToAboutAsync()
    {
        IsSettingsOpen = false;
        await Task.Delay(100);
        await Shell.Current.GoToAsync("AboutPage");
    }

    [RelayCommand]
    private async Task OpenAdvancedSearchAsync()
    {
        IsSettingsOpen = false;
        await Task.Delay(100);

        var navigationParameter = new Dictionary<string, object>
        {
            { "CurrentFilter", AdvancedSearchFilter != null ? (SearchFilter)AdvancedSearchFilter.Clone() : new SearchFilter() }
        };

        await Shell.Current.GoToAsync("advancedsearch", navigationParameter);
    }

    public async Task ApplySearchFilter(SearchFilter filter)
    {
        AdvancedSearchFilter = filter;
        if (!_isInitialized)
        {
            await InitializeAsync();
            return;
        }

        ApplyFiltersAndResetPage();
    }

    [RelayCommand]
    private async Task ExportCsvAsync()
    {
        try
        {
            var path = await _dataService.ExportToCsvAsync();
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
        _isInitialized = false;
        await InitializeAsync();
    }

    [RelayCommand]
    private async Task RefreshAsync()
    {
        if (!_isInitialized)
        {
            await InitializeAsync();
            return;
        }

        await LoadDataAsync();
    }

    [RelayCommand]
    private void LoadMore()
    {
        if (IsLoadingMore || !HasMoreItems) return;
        _ = LoadMoreAsync();
    }

    partial void OnSelectedCategoryChanged(SelectableCategory value)
    {
        // 取消其他分类的选中状态
        foreach (var cat in Categories)
        {
            if (cat != value)
                cat.IsSelected = false;
        }

        if (value != null)
            value.IsSelected = true;

        if (_suppressCategorySelectionLoad)
            return;

        ApplyFiltersAndResetPage();
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
            ApplyFiltersAndResetPage();
        }
        catch (TaskCanceledException) { }
    }

    [RelayCommand]
    private async Task InitializeAsync()
    {
        if (_isInitialized)
            return;

        await _initializeLock.WaitAsync();
        Exception? initializeError = null;
        try
        {
            if (_isInitialized)
                return;

            IsLoading = true;
            try
            {
                await LoadCategoriesAsync();
                _isInitialized = true;
                await LoadDataAsync();
            }
            catch (Exception ex)
            {
                ResetLoadedData();
                initializeError = ex;
            }
            finally
            {
                IsLoading = false;
                OnPropertyChanged(nameof(IsEmpty));
            }
        }
        finally
        {
            _initializeLock.Release();
        }

        if (initializeError is not null)
            _ = ShowLoadErrorAsync(initializeError);
    }

    private async Task LoadCategoriesAsync()
    {
        _suppressCategorySelectionLoad = true;
        try
        {
            Categories.Clear();
            Categories.Add(new SelectableCategory(new Category { Id = Guid.Empty, Name = "全部" }, isSelected: true)
            {
                OnSelect = (cat) => SelectedCategory = cat
            });
            var categories = await _dataService.GetCategoriesAsync();
            foreach (var cat in categories.Where(c => c.IsActive).OrderBy(c => c.SortOrder))
            {
                Categories.Add(new SelectableCategory(cat)
                {
                    OnSelect = (c) => SelectedCategory = c
                });
            }
            SelectedCategory = Categories[0];
        }
        finally
        {
            _suppressCategorySelectionLoad = false;
        }
    }

    private async Task LoadDataAsync()
    {
        await _loadLock.WaitAsync();
        Exception? loadError = null;

        try
        {
            var result = await _dataService.GetItemsWithStatisticsAsync();

            TotalSpentText = $"¥{result.TotalSpent:F1}";
            ValidCountText = $"{result.ValidItems} 件";
            TotalItemsText = $"{result.TotalItems} 件";

            _sourceItems = result.Items;
            ApplyFiltersAndResetPage();
        }
        catch (Exception ex)
        {
            ResetLoadedData();
            loadError = ex;
        }
        finally
        {
            IsLoading = false;
            _loadLock.Release();
            OnPropertyChanged(nameof(IsEmpty));
        }

        if (loadError is not null)
            _ = ShowLoadErrorAsync(loadError);
    }

    private void RefreshStatisticsFromCache()
    {
        var validItems = _sourceItems
            .Where(i => i.ExpiryStatus != Enums.ExpiryStatus.Expired)
            .ToList();
        var totalSpent = validItems.Sum(i => (i.PurchasePrice ?? 0) * i.Quantity);

        TotalSpentText = $"¥{totalSpent:F1}";
        ValidCountText = $"{validItems.Count} 件";
        TotalItemsText = $"{_sourceItems.Count} 件";
    }

    private void ApplyFiltersAndResetPage()
    {
        var items = _sourceItems.AsEnumerable();

        if (SelectedCategory?.Category?.Id is { } categoryId && categoryId != Guid.Empty)
            items = items.Where(i => i.CategoryId == categoryId);

        if (!string.IsNullOrWhiteSpace(SearchText))
            items = items.Where(i => i.ItemName.Contains(SearchText, StringComparison.OrdinalIgnoreCase));

        // 应用高级搜索过滤器
        if (AdvancedSearchFilter != null && AdvancedSearchFilter.IsActive)
        {
            var filter = AdvancedSearchFilter;

            // 关键词搜索
            if (!string.IsNullOrWhiteSpace(filter.Keyword))
                items = items.Where(i => i.ItemName.Contains(filter.Keyword, StringComparison.OrdinalIgnoreCase) ||
                                            (i.Brand != null && i.Brand.Contains(filter.Keyword, StringComparison.OrdinalIgnoreCase)));

            // 价格区间
            if (filter.MinPrice.HasValue)
                items = items.Where(i => i.PurchasePrice.HasValue && i.PurchasePrice.Value >= filter.MinPrice.Value);
            if (filter.MaxPrice.HasValue)
                items = items.Where(i => i.PurchasePrice.HasValue && i.PurchasePrice.Value <= filter.MaxPrice.Value);

            // 购买日期
            if (filter.PurchaseDateFrom.HasValue)
                items = items.Where(i => i.PurchaseDate.HasValue && i.PurchaseDate.Value >= filter.PurchaseDateFrom.Value);
            if (filter.PurchaseDateTo.HasValue)
                items = items.Where(i => i.PurchaseDate.HasValue && i.PurchaseDate.Value <= filter.PurchaseDateTo.Value);

            // 保质期
            if (filter.ExpiryDateFrom.HasValue)
                items = items.Where(i => i.ExpiryDate.HasValue && i.ExpiryDate.Value >= filter.ExpiryDateFrom.Value);
            if (filter.ExpiryDateTo.HasValue)
                items = items.Where(i => i.ExpiryDate.HasValue && i.ExpiryDate.Value <= filter.ExpiryDateTo.Value);

            // 分类
            if (filter.CategoryId.HasValue)
                items = items.Where(i => i.CategoryId == filter.CategoryId.Value);

            // 只显示有保质期的
            if (filter.HasExpiry)
                items = items.Where(i => i.ExpiryDate.HasValue);

            // 只显示临期/已过期
            if (filter.OnlyExpiring)
                items = items.Where(i => i.ExpiryStatus != Enums.ExpiryStatus.Safe && i.ExpiryStatus != Enums.ExpiryStatus.NoExpiry);

            // 只显示已过期
            if (filter.OnlyExpired)
                items = items.Where(i => i.ExpiryStatus == Enums.ExpiryStatus.Expired);
        }

        _allItems = items.OrderByDescending(i => i.PurchaseDate).ToList();
        _loadedCount = 0;
        Items.Clear();

        AppendPage();
    }

    private void ResetLoadedData()
    {
        _sourceItems = [];
        _allItems = [];
        _loadedCount = 0;
        Items.Clear();
        HasMoreItems = false;
        TotalSpentText = "¥0.0";
        ValidCountText = "0 件";
        TotalItemsText = "0 件";
    }

    private static Task ShowLoadErrorAsync(Exception ex)
    {
        return MainThread.InvokeOnMainThreadAsync(async () =>
        {
            if (Shell.Current is not null)
                await Shell.Current.DisplayAlertAsync("加载失败", $"物品库数据加载失败：{ex.Message}", "确定");
        });
    }

    private async Task LoadMoreAsync()
    {
        try
        {
            IsLoadingMore = true;
            await Task.Delay(100);
            AppendPage();
        }
        finally
        {
            IsLoadingMore = false;
        }
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
