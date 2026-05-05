using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class AddItemViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;
    private readonly SemaphoreSlim _categoryLoadLock = new(1, 1);
    private Guid _editingItemId;
    private DateTime _originalCreatedAt;
    private bool _categoriesLoaded;

    public ObservableCollection<Category> Categories { get; } = [];

    public string PageTitle => IsEditMode ? "编辑物品" : "添加物品";
    public string FormHeaderTitle => IsEditMode ? "编辑信息" : "基础信息";
    public string FormHeaderIcon => IsEditMode ? "\u270F\uFE0F" : "\U0001F4E6";
    public string FormSubtitle => IsEditMode ? "正在修改已有物品" : "创建新的物品记录";
    public string SaveButtonText => IsEditMode ? "更新" : "保存";
    public bool HasBarcode => !string.IsNullOrWhiteSpace(Barcode);
    public string BarcodeDisplayText => HasBarcode ? $"条码: {Barcode?.Trim()}" : string.Empty;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(PageTitle))]
    [NotifyPropertyChangedFor(nameof(FormHeaderTitle))]
    [NotifyPropertyChangedFor(nameof(FormHeaderIcon))]
    [NotifyPropertyChangedFor(nameof(FormSubtitle))]
    [NotifyPropertyChangedFor(nameof(SaveButtonText))]
    private partial bool IsEditMode { get; set; }

    [ObservableProperty]
    private partial string ItemName { get; set; } = string.Empty;

    [ObservableProperty]
    private partial Category? SelectedCategory { get; set; }

    [ObservableProperty]
    private partial string? Barcode { get; set; }

    [ObservableProperty]
    private partial string? Brand { get; set; }

    [ObservableProperty]
    private partial string? Location { get; set; }

    [ObservableProperty]
    private partial DateTime? PurchaseDate { get; set; } = DateTime.Today;

    [ObservableProperty]
    private partial decimal? PurchasePrice { get; set; }

    [ObservableProperty]
    private partial DateTime? ExpiryDate { get; set; } = DateTime.Today.AddDays(7);

    [ObservableProperty]
    private partial bool NoExpiry { get; set; }

    [ObservableProperty]
    private partial bool TrackDailyCost { get; set; } = true;

    [ObservableProperty]
    private partial int Quantity { get; set; } = 1;

    [ObservableProperty]
    private partial string? Notes { get; set; }

    [ObservableProperty]
    private partial bool IsSaving { get; set; }

    [ObservableProperty]
    private partial bool IsLoadingItem { get; set; }

    [ObservableProperty]
    private partial string? ErrorMessage { get; set; }

    [ObservableProperty]
    private partial string? ItemNameError { get; set; }

    [ObservableProperty]
    private partial string? CategoryError { get; set; }

    public AddItemViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = EnsureCategoriesLoadedAsync();
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.TryGetValue("itemId", out var itemIdObj) && TryGetItemId(itemIdObj, out var itemId))
        {
            SetEditMode();
            _editingItemId = itemId;
            _ = LoadExistingDataAsync(itemId);
        }

        if (query.TryGetValue("barcode", out var barcodeObj) && barcodeObj?.ToString() is string barcodeValue)
        {
            Barcode = string.IsNullOrWhiteSpace(barcodeValue) ? null : barcodeValue.Trim();
        }
    }

    private async Task InitializeAsync()
    {
        await EnsureCategoriesLoadedAsync();
    }

    private async Task LoadExistingDataAsync(Guid itemId)
    {
        IsLoadingItem = true;
        ErrorMessage = null;

        try
        {
            var item = await _dataService.GetItemByIdAsync(itemId);
            if (item is null)
            {
                ErrorMessage = "没有找到要编辑的物品";
                return;
            }

            _editingItemId = item.Id;
            _originalCreatedAt = item.CreatedAt;

            SetEditMode();
            ItemName = item.Name;
            Brand = item.Brand;
            Location = item.DefaultLocation;
            Barcode = string.IsNullOrWhiteSpace(item.Barcode) ? null : item.Barcode.Trim();
            PurchaseDate = item.PurchaseDate;
            PurchasePrice = item.PurchasePrice;
            ExpiryDate = item.ExpiryDate;
            NoExpiry = item.ExpiryDate is null;
            TrackDailyCost = item.TrackDailyCost;
            Quantity = item.Quantity;
            Notes = item.Notes;

            await EnsureCategoriesLoadedAsync();
            SelectedCategory = Categories.FirstOrDefault(c => c.Id == item.CategoryId);

            if (SelectedCategory is null)
                ErrorMessage = "原分类不存在，请重新选择分类";
        }
        catch
        {
            ErrorMessage = "加载编辑信息失败";
        }
        finally
        {
            IsLoadingItem = false;
        }
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (!ValidateRequiredFields())
            return;

        IsSaving = true;
        ErrorMessage = null;

        try
        {
            var category = SelectedCategory!;

            var item = new Item
            {
                Id = IsEditMode ? _editingItemId : Guid.NewGuid(),
                Name = ItemName.Trim(),
                CategoryId = category.Id,
                Barcode = string.IsNullOrWhiteSpace(Barcode) ? null : Barcode.Trim(),
                Brand = Brand,
                Icon = category.Icon ?? "\U0001F4E6",
                DefaultLocation = Location,
                PurchaseDate = PurchaseDate,
                PurchasePrice = PurchasePrice,
                ExpiryDate = NoExpiry ? null : ExpiryDate,
                Quantity = Math.Max(1, Quantity),
                TrackDailyCost = TrackDailyCost,
                Notes = Notes,
                CreatedAt = IsEditMode ? _originalCreatedAt : DateTime.Now,
                UpdatedAt = DateTime.Now,
            };

            await _dataService.SaveItemAsync(item);
            await Shell.Current.GoToAsync("..");
        }
        catch
        {
            ErrorMessage = "保存失败，请稍后重试";
        }
        finally
        {
            IsSaving = false;
        }
    }

    [RelayCommand]
    private async Task ScanBarcodeAsync()
    {
        await Shell.Current.GoToAsync("scanner");
    }

    [RelayCommand]
    private void ClearBarcode()
    {
        Barcode = null;
    }

    partial void OnItemNameChanged(string value)
    {
        if (!string.IsNullOrWhiteSpace(value))
            ItemNameError = null;

        RefreshValidationSummary();
    }

    partial void OnSelectedCategoryChanged(Category? value)
    {
        if (value is not null)
            CategoryError = null;

        RefreshValidationSummary();
    }

    partial void OnBarcodeChanged(string? value)
    {
        OnPropertyChanged(nameof(HasBarcode));
        OnPropertyChanged(nameof(BarcodeDisplayText));
    }

    partial void OnNoExpiryChanged(bool value)
    {
        if (value)
            ExpiryDate = null;
        else
            ExpiryDate = DateTime.Today.AddDays(7);
    }

    private async Task EnsureCategoriesLoadedAsync()
    {
        if (_categoriesLoaded)
            return;

        await _categoryLoadLock.WaitAsync();
        try
        {
            if (_categoriesLoaded)
                return;

            Categories.Clear();
            var categories = await _dataService.GetCategoriesAsync();
            foreach (var cat in categories.Where(c => c.IsActive).OrderBy(c => c.SortOrder))
                Categories.Add(cat);

            _categoriesLoaded = true;
        }
        finally
        {
            _categoryLoadLock.Release();
        }
    }

    private bool ValidateRequiredFields()
    {
        ItemNameError = string.IsNullOrWhiteSpace(ItemName) ? "请输入物品名称" : null;
        CategoryError = SelectedCategory is null ? "请选择分类" : null;
        RefreshValidationSummary();

        return ItemNameError is null && CategoryError is null;
    }

    private void RefreshValidationSummary()
    {
        ErrorMessage = ItemNameError is not null || CategoryError is not null
            ? "请先填写红点标记的必填项"
            : null;
    }

    private void SetEditMode()
    {
        if (!IsEditMode)
            IsEditMode = true;
    }

    private static bool TryGetItemId(object? value, out Guid itemId)
    {
        switch (value)
        {
            case Guid guid:
                itemId = guid;
                return true;
            case string text when Guid.TryParse(text, out var parsed):
                itemId = parsed;
                return true;
            default:
                itemId = Guid.Empty;
                return false;
        }
    }
}
