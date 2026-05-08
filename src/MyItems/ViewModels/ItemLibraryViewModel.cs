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
    private readonly IItemQueryCache _itemQueryCache;
    private const int PageSize = 10;

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
        : this(dataService, new ItemQueryCache(dataService))
    {
    }

    public ItemLibraryViewModel(IDataService dataService, IItemQueryCache itemQueryCache)
    {
        _dataService = dataService;
        _itemQueryCache = itemQueryCache;
    }

    [RelayCommand]
    private void ToggleSettings()
    {
        IsSettingsOpen = !IsSettingsOpen;
    }

    [RelayCommand]
    private async Task DeleteItemAsync(Guid itemId)
    {
        var item = Items.FirstOrDefault(i => i.ItemId == itemId);
        var name = item?.ItemName ?? "这个物品";
        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{name}」吗？", "删除", "取消");
        if (!confirm) return;

        await _dataService.DeleteItemAsync(itemId);
        _itemQueryCache.Invalidate();
        await LoadDataAsync();
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

        await LoadDataAsync();
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
        _itemQueryCache.Invalidate();
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
    private async Task LoadMoreAsync()
    {
        if (IsLoadingMore || !HasMoreItems) return;

        try
        {
            IsLoadingMore = true;
            var result = await LoadPageAsync(_loadedCount);
            AppendPage(result, replace: false);
        }
        finally
        {
            IsLoadingMore = false;
        }
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
            var result = await _dataService.GetStatisticsAsync();

            TotalSpentText = $"¥{result.TotalSpent:F1}";
            ValidCountText = $"{result.ValidItems} 件";
            TotalItemsText = $"{result.TotalItems} 件";

            var page = await LoadPageAsync(0);
            AppendPage(page, replace: true);
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

    private Task<PagedItemDisplayResult> LoadPageAsync(int offset)
    {
        var categoryId = SelectedCategory?.Category?.Id;
        var options = new ItemQueryOptions(
            Offset: offset,
            Limit: PageSize,
            CategoryId: categoryId is { } id && id != Guid.Empty ? id : null,
            SearchText: SearchText,
            AdvancedSearchFilter: AdvancedSearchFilter);
        return _dataService.GetItemDisplayPageAsync(options);
    }

    private void ResetLoadedData()
    {
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

    private void AppendPage(PagedItemDisplayResult result, bool replace)
    {
        if (replace)
        {
            _loadedCount = 0;
            Items.Clear();
        }

        foreach (var item in result.Items)
            Items.Add(item);

        _loadedCount += result.Items.Count;
        HasMoreItems = _loadedCount < result.TotalCount;
        OnPropertyChanged(nameof(IsEmpty));
    }
}
