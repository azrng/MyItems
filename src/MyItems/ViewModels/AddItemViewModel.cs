using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class AddItemViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;
    private Guid _editingBatchId;
    private Guid _editingItemId;
    private DateTime _originalItemCreatedAt;
    private DateTime _originalBatchCreatedAt;

    public ObservableCollection<Category> Categories { get; } = [];

    public string PageTitle => IsEditMode ? "编辑物品" : "添加物品";
    public string SaveButtonText => IsEditMode ? "更新" : "保存";

    [ObservableProperty]
    private bool isEditMode;

    [ObservableProperty]
    private string itemName = string.Empty;

    [ObservableProperty]
    private Category? selectedCategory;

    [ObservableProperty]
    private string? barcode;

    [ObservableProperty]
    private string? brand;

    [ObservableProperty]
    private string? location;

    [ObservableProperty]
    private DateTime? purchaseDate = DateTime.Today;

    [ObservableProperty]
    private decimal? purchasePrice;

    [ObservableProperty]
    private DateTime? expiryDate = DateTime.Today.AddMonths(1);

    [ObservableProperty]
    private bool noExpiry;

    [ObservableProperty]
    private bool trackDailyCost = true;

    [ObservableProperty]
    private int quantity = 1;

    [ObservableProperty]
    private string? notes;

    [ObservableProperty]
    private bool isSaving;

    [ObservableProperty]
    private string? errorMessage;

    public AddItemViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = InitializeAsync();
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.TryGetValue("batchId", out var batchIdObj) && Guid.TryParse(batchIdObj?.ToString(), out var batchId))
        {
            _editingBatchId = batchId;
            _ = LoadExistingDataAsync(batchId);
        }
    }

    private async Task InitializeAsync()
    {
        await LoadCategoriesAsync();
    }

    private async Task LoadExistingDataAsync(Guid batchId)
    {
        var batches = await _dataService.GetBatchDisplayDtosAsync();
        var batchDto = batches.FirstOrDefault(b => b.BatchId == batchId);
        if (batchDto is null) return;

        var items = await _dataService.GetItemsAsync();
        var item = items.FirstOrDefault(i => i.Id == batchDto.ItemId);
        if (item is null) return;

        var batch = (await _dataService.GetBatchesAsync()).FirstOrDefault(b => b.Id == batchId);
        if (batch is null) return;

        _editingItemId = item.Id;
        _editingBatchId = batchId;
        _originalItemCreatedAt = item.CreatedAt;
        _originalBatchCreatedAt = batch.CreatedAt;

        IsEditMode = true;
        ItemName = item.Name;
        Brand = item.Brand;
        Location = item.DefaultLocation;
        Barcode = item.Barcode;
        PurchaseDate = batch.PurchaseDate;
        PurchasePrice = batch.PurchasePrice;
        ExpiryDate = batch.ExpiryDate;
        NoExpiry = batch.ExpiryDate is null;
        TrackDailyCost = batch.TrackDailyCost;
        Quantity = batch.Quantity;
        Notes = batch.Notes;

        await LoadCategoriesAsync();
        SelectedCategory = Categories.FirstOrDefault(c => c.Id == item.CategoryId);

        OnPropertyChanged(nameof(PageTitle));
        OnPropertyChanged(nameof(SaveButtonText));
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (string.IsNullOrWhiteSpace(ItemName))
        {
            ErrorMessage = "请输入物品名称";
            return;
        }

        if (SelectedCategory is null)
        {
            ErrorMessage = "请选择分类";
            return;
        }

        IsSaving = true;
        ErrorMessage = null;

        var category = await _dataService.GetCategoriesAsync()
            .ContinueWith(t => t.Result.FirstOrDefault(c => c.Id == SelectedCategory.Id));

        if (IsEditMode)
        {
            var item = new Item
            {
                Id = _editingItemId,
                Name = ItemName.Trim(),
                CategoryId = SelectedCategory.Id,
                Barcode = Barcode,
                Brand = Brand,
                Icon = category?.Icon ?? "\U0001F4E6",
                DefaultLocation = Location,
                CreatedAt = _originalItemCreatedAt,
                UpdatedAt = DateTime.Now,
            };
            await _dataService.SaveItemAsync(item);

            var batch = new Batch
            {
                Id = _editingBatchId,
                ItemId = _editingItemId,
                PurchaseDate = PurchaseDate,
                PurchasePrice = PurchasePrice,
                ExpiryDate = NoExpiry ? null : ExpiryDate,
                Location = Location,
                Quantity = Math.Max(1, Quantity),
                TrackDailyCost = TrackDailyCost,
                Notes = Notes,
                BatchLabel = DateTime.Now.ToString("yyyyMMddHHmmss"),
                CreatedAt = _originalBatchCreatedAt,
            };
            await _dataService.SaveBatchAsync(batch);
        }
        else
        {
            var item = new Item
            {
                Id = Guid.NewGuid(),
                Name = ItemName.Trim(),
                CategoryId = SelectedCategory.Id,
                Barcode = Barcode,
                Brand = Brand,
                Icon = category?.Icon ?? "\U0001F4E6",
                DefaultLocation = Location,
                CreatedAt = DateTime.Now,
                UpdatedAt = DateTime.Now,
            };
            await _dataService.SaveItemAsync(item);

            var batch = new Batch
            {
                Id = Guid.NewGuid(),
                ItemId = item.Id,
                PurchaseDate = PurchaseDate,
                PurchasePrice = PurchasePrice,
                ExpiryDate = NoExpiry ? null : ExpiryDate,
                Location = Location,
                Quantity = Math.Max(1, Quantity),
                TrackDailyCost = TrackDailyCost,
                Notes = Notes,
                BatchLabel = DateTime.Now.ToString("yyyyMMddHHmmss"),
                CreatedAt = DateTime.Now,
            };
            await _dataService.SaveBatchAsync(batch);
        }

        IsSaving = false;
        await Shell.Current.GoToAsync("..");
    }

    [RelayCommand]
    private async Task ScanBarcodeAsync()
    {
        await Shell.Current.DisplayAlertAsync("扫码", "扫码功能将在后续版本实现", "确定");
    }

    partial void OnNoExpiryChanged(bool value)
    {
        if (value)
            ExpiryDate = null;
        else
            ExpiryDate = DateTime.Today.AddMonths(1);
    }

    private async Task LoadCategoriesAsync()
    {
        Categories.Clear();
        var categories = await _dataService.GetCategoriesAsync();
        foreach (var cat in categories.Where(c => c.IsActive).OrderBy(c => c.SortOrder))
            Categories.Add(cat);
    }
}
