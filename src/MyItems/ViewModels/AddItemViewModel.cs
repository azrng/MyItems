using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class AddItemViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;
    private readonly SemaphoreSlim _categoryLoadLock = new(1, 1);
    private readonly SemaphoreSlim _itemLoadLock = new(1, 1);
    private Guid _editingItemId;
    private DateTime _originalCreatedAt;
    private bool _categoriesLoaded;
    private bool _hasLoadedEditingItem;
    private bool _isPopulatingExistingItem;
    private Guid? _pendingSelectedCategoryId;
    private ItemDisplayDto? _pendingDraft;
    private ItemDisplayDto? _uiHydrationDraft;

    public ObservableCollection<Category> Categories { get; } = [];

    public string PageTitle => IsEditMode ? "编辑物品" : "添加物品";
    public string FormHeaderTitle => IsEditMode ? "编辑信息" : "基础信息";
    public string FormHeaderIcon => IsEditMode ? "\u270F\uFE0F" : "\U0001F4E6";
    public string FormSubtitle => IsEditMode ? "正在修改已有物品" : "创建新的物品记录";
    public string SaveButtonText => IsEditMode ? "更新" : "保存";
    public string HeaderIcon => SelectedCategory?.Icon ?? FormHeaderIcon;
    public bool HasBarcode => !string.IsNullOrWhiteSpace(Barcode);
    public string BarcodeDisplayText => HasBarcode ? $"条码: {Barcode?.Trim()}" : string.Empty;

    public AddItemFormSnapshot CurrentFormSnapshot => new(
        ItemName,
        SelectedCategory,
        Brand,
        Location,
        Quantity,
        Barcode,
        PurchaseDate,
        PurchasePrice,
        ExpiryDate,
        NoExpiry,
        TrackDailyCost,
        Notes);

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
    }

    public void PrepareForEdit(ItemDisplayDto draft)
    {
        Debug.WriteLine($"[AddItem] PrepareForEdit itemId={draft.ItemId}, name={draft.ItemName}, categoryId={draft.CategoryId}");
        ErrorMessage = null;
        ItemNameError = null;
        CategoryError = null;
        _uiHydrationDraft = draft;
        PrimeFromDraft(draft);
        IsLoadingItem = false;
    }

    public bool HasPendingUiHydrationDraft => _uiHydrationDraft is not null;

    public void ApplyFormSnapshot(AddItemFormSnapshot snapshot)
    {
        ItemName = snapshot.ItemName;
        SelectedCategory = snapshot.SelectedCategory;
        Brand = string.IsNullOrWhiteSpace(snapshot.Brand) ? null : snapshot.Brand.Trim();
        Location = string.IsNullOrWhiteSpace(snapshot.Location) ? null : snapshot.Location.Trim();
        Quantity = Math.Clamp(snapshot.Quantity, 1, 999);
        Barcode = string.IsNullOrWhiteSpace(snapshot.Barcode) ? null : snapshot.Barcode.Trim();
        PurchaseDate = snapshot.PurchaseDate;
        PurchasePrice = snapshot.PurchasePrice;
        NoExpiry = snapshot.NoExpiry;
        ExpiryDate = snapshot.NoExpiry ? null : snapshot.ExpiryDate;
        TrackDailyCost = snapshot.TrackDailyCost;
        Notes = string.IsNullOrWhiteSpace(snapshot.Notes) ? null : snapshot.Notes.Trim();
    }

    public void ApplyItemIdQuery(string? itemIdText)
    {
        if (!Guid.TryParse(itemIdText, out var itemId))
            return;

        if (_hasLoadedEditingItem && _editingItemId == itemId)
            return;

        SetEditMode();
        _editingItemId = itemId;
        _hasLoadedEditingItem = false;
        IsLoadingItem = true;
        _ = EnsureEditingItemLoadedAsync();
    }

    public void ApplyBarcodeQuery(string? barcodeValue)
    {
        Barcode = string.IsNullOrWhiteSpace(barcodeValue) ? null : barcodeValue.Trim();
    }

    public void ApplyEditDraftJson(string? editDraftJson)
    {
        if (string.IsNullOrWhiteSpace(editDraftJson))
            return;

        try
        {
            var json = Uri.UnescapeDataString(editDraftJson);
            var draft = JsonSerializer.Deserialize<ItemDisplayDto>(json);
            if (draft is null)
                return;

            _pendingDraft = draft;
            SetEditMode();
            _editingItemId = draft.ItemId;
            _hasLoadedEditingItem = false;
            IsLoadingItem = true;
            _ = EnsureEditingItemLoadedAsync();
        }
        catch
        {
            // ignore malformed route payload and fallback to db query
        }
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.TryGetValue("itemId", out var itemIdObj) && TryGetItemId(itemIdObj, out var itemId))
            ApplyItemIdQuery(itemId.ToString());

        if (query.TryGetValue("barcode", out var barcodeObj) && barcodeObj?.ToString() is string barcodeValue)
            ApplyBarcodeQuery(barcodeValue);

        if (query.TryGetValue("editDraft", out var editDraftObj))
        {
            if (editDraftObj is ItemDisplayDto draft)
                PrepareForEdit(draft);
            else if (editDraftObj?.ToString() is string editDraftJson)
                ApplyEditDraftJson(editDraftJson);
        }
    }

    public async Task OnAppearingAsync()
    {
        Debug.WriteLine($"[AddItem] OnAppearing isEdit={IsEditMode}, itemId={_editingItemId}, loaded={_hasLoadedEditingItem}, itemName={ItemName}");
        await EnsureCategoriesLoadedAsync();

        if (_uiHydrationDraft is not null)
        {
            ApplyPendingSelectedCategory();
            IsLoadingItem = false;
            return;
        }

        ApplyPendingSelectedCategory();
        await EnsureEditingItemLoadedAsync();
    }

    public Task ApplyDeferredUiHydrationAsync()
    {
        return ApplyUiHydrationDraftAsync();
    }

    private async Task ApplyUiHydrationDraftAsync()
    {
        var draft = _uiHydrationDraft;
        if (draft is null)
            return;

        await Task.Yield();
        await EnsureCategoriesLoadedAsync();

        _uiHydrationDraft = null;
        PrimeFromDraft(draft);
        ApplyPendingSelectedCategory();

        if (SelectedCategory is null)
            ErrorMessage = "原分类不存在，请重新选择分类";

        IsLoadingItem = false;
        Debug.WriteLine($"[AddItem] ApplyUiHydrationDraftAsync itemId={draft.ItemId}, itemName={ItemName}, category={(SelectedCategory?.Name ?? "null")}");
    }

    private async Task EnsureEditingItemLoadedAsync()
    {
        if (_editingItemId == Guid.Empty || _hasLoadedEditingItem)
            return;

        await _itemLoadLock.WaitAsync();
        try
        {
            if (_editingItemId == Guid.Empty || _hasLoadedEditingItem)
                return;

            await LoadExistingDataAsync(_editingItemId);
        }
        finally
        {
            _itemLoadLock.Release();
        }
    }

    private async Task LoadExistingDataAsync(Guid itemId)
    {
        if (_hasLoadedEditingItem)
            return;

        IsLoadingItem = true;
        ErrorMessage = null;
        ItemNameError = null;
        CategoryError = null;

        try
        {
            Debug.WriteLine($"[AddItem] LoadExistingDataAsync start itemId={itemId}");
            if (_pendingDraft is not null && _pendingDraft.ItemId == itemId)
            {
                var routeDraft = _pendingDraft;
                _pendingDraft = null;
                await PopulateFromDraftAsync(routeDraft);
                return;
            }

            var item = await _dataService.GetItemByIdAsync(itemId);
            if (item is null)
            {
                Debug.WriteLine($"[AddItem] LoadExistingDataAsync item not found itemId={itemId}");
                ErrorMessage = "没有找到要编辑的物品";
                return;
            }

            _editingItemId = item.Id;
            _originalCreatedAt = item.CreatedAt;
            _isPopulatingExistingItem = true;
            SetEditMode();
            ItemName = item.Name;
            Brand = item.Brand;
            Location = item.DefaultLocation;
            Barcode = string.IsNullOrWhiteSpace(item.Barcode) ? null : item.Barcode.Trim();
            PurchaseDate = item.PurchaseDate;
            PurchasePrice = item.PurchasePrice;
            NoExpiry = item.ExpiryDate is null;
            ExpiryDate = item.ExpiryDate;
            TrackDailyCost = item.TrackDailyCost;
            Quantity = item.Quantity;
            Notes = item.Notes;
            Debug.WriteLine($"[AddItem] LoadExistingDataAsync loaded itemId={item.Id}, name={item.Name}, categoryId={item.CategoryId}");
            _isPopulatingExistingItem = false;

            await EnsureCategoriesLoadedAsync();
            _pendingSelectedCategoryId = item.CategoryId;
            ApplyPendingSelectedCategory();

            if (SelectedCategory is null)
                ErrorMessage = "原分类不存在，请重新选择分类";

            _hasLoadedEditingItem = true;
        }
        catch
        {
            ErrorMessage = "加载编辑信息失败";
        }
        finally
        {
            _isPopulatingExistingItem = false;
            IsLoadingItem = false;
        }
    }

    private async Task PopulateFromDraftAsync(Models.DTOs.ItemDisplayDto draft)
    {
        PrimeFromDraft(draft);

        await EnsureCategoriesLoadedAsync();
        ApplyPendingSelectedCategory();

        if (SelectedCategory is null)
            ErrorMessage = "原分类不存在，请重新选择分类";

        _hasLoadedEditingItem = true;
    }

    private void PrimeFromDraft(ItemDisplayDto draft)
    {
        Debug.WriteLine($"[AddItem] PrimeFromDraft itemId={draft.ItemId}, name={draft.ItemName}, categoryId={draft.CategoryId}");
        _editingItemId = draft.ItemId;
        _originalCreatedAt = draft.CreatedAt;
        _pendingSelectedCategoryId = draft.CategoryId;
        _pendingDraft = draft;
        _hasLoadedEditingItem = true;
        _isPopulatingExistingItem = true;
        SetEditMode();
        ItemName = draft.ItemName;
        Brand = draft.Brand;
        Location = draft.Location;
        Barcode = string.IsNullOrWhiteSpace(draft.Barcode) ? null : draft.Barcode.Trim();
        PurchaseDate = draft.PurchaseDate;
        PurchasePrice = draft.PurchasePrice;
        NoExpiry = draft.ExpiryDate is null;
        ExpiryDate = draft.ExpiryDate;
        TrackDailyCost = draft.TrackDailyCost;
        Quantity = draft.Quantity;
        Notes = draft.Notes;
        _isPopulatingExistingItem = false;
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
            Debug.WriteLine($"[AddItem] Save start isEdit={IsEditMode}, itemId={_editingItemId}, name={ItemName}, categoryId={category.Id}, quantity={Quantity}");

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
            Debug.WriteLine($"[AddItem] Save success itemId={item.Id}, name={item.Name}");
            await CloseAsync();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[AddItem] Save failed: {ex}");
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

    [RelayCommand]
    private void DecreaseQuantity()
    {
        Quantity = Math.Max(1, Quantity - 1);
    }

    [RelayCommand]
    private void IncreaseQuantity()
    {
        Quantity = Math.Min(999, Quantity + 1);
    }

    partial void OnItemNameChanged(string value)
    {
        Debug.WriteLine($"[AddItem] OnItemNameChanged value={value}");
        if (!string.IsNullOrWhiteSpace(value))
            ItemNameError = null;

        RefreshValidationSummary();
    }

    partial void OnSelectedCategoryChanged(Category? value)
    {
        if (value is not null)
            CategoryError = null;

        OnPropertyChanged(nameof(HeaderIcon));
        RefreshValidationSummary();
    }

    partial void OnBarcodeChanged(string? value)
    {
        OnPropertyChanged(nameof(HasBarcode));
        OnPropertyChanged(nameof(BarcodeDisplayText));
    }

    partial void OnNoExpiryChanged(bool value)
    {
        if (_isPopulatingExistingItem)
            return;

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
            ApplyPendingSelectedCategory();
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

    [RelayCommand]
    private async Task GoBackAsync()
    {
        await CloseAsync();
    }

    private static async Task CloseAsync()
    {
        var navigation = Shell.Current.Navigation;
        if (navigation.ModalStack.Count > 0)
            await navigation.PopModalAsync();
        else
            await navigation.PopAsync();
    }

    private void ApplyPendingSelectedCategory()
    {
        if (!_pendingSelectedCategoryId.HasValue || Categories.Count == 0)
            return;

        SelectedCategory = Categories.FirstOrDefault(c => c.Id == _pendingSelectedCategoryId.Value);
        _pendingSelectedCategoryId = null;
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

public sealed record AddItemFormSnapshot(
    string ItemName,
    Category? SelectedCategory,
    string? Brand,
    string? Location,
    int Quantity,
    string? Barcode,
    DateTime? PurchaseDate,
    decimal? PurchasePrice,
    DateTime? ExpiryDate,
    bool NoExpiry,
    bool TrackDailyCost,
    string? Notes);
