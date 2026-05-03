using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class AddItemViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;
    private Guid _editingItemId;
    private DateTime _originalCreatedAt;

    public ObservableCollection<Category> Categories { get; } = [];

    public string PageTitle => IsEditMode ? "编辑物品" : "添加物品";
    public string SaveButtonText => IsEditMode ? "更新" : "保存";

    [ObservableProperty]
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
    private partial string? ErrorMessage { get; set; }

    public AddItemViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = InitializeAsync();
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.TryGetValue("itemId", out var itemIdObj) && Guid.TryParse(itemIdObj?.ToString(), out var itemId))
        {
            _editingItemId = itemId;
            _ = LoadExistingDataAsync(itemId);
        }

        if (query.TryGetValue("barcode", out var barcodeObj) && barcodeObj?.ToString() is string barcodeValue)
        {
            Barcode = barcodeValue;
        }
    }

    private async Task InitializeAsync()
    {
        await LoadCategoriesAsync();
    }

    private async Task LoadExistingDataAsync(Guid itemId)
    {
        var item = await _dataService.GetItemByIdAsync(itemId);
        if (item is null) return;

        _editingItemId = item.Id;
        _originalCreatedAt = item.CreatedAt;

        IsEditMode = true;
        ItemName = item.Name;
        Brand = item.Brand;
        Location = item.DefaultLocation;
        Barcode = item.Barcode;
        PurchaseDate = item.PurchaseDate;
        PurchasePrice = item.PurchasePrice;
        ExpiryDate = item.ExpiryDate;
        NoExpiry = item.ExpiryDate is null;
        TrackDailyCost = item.TrackDailyCost;
        Quantity = item.Quantity;
        Notes = item.Notes;

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

        var category = SelectedCategory;

        var item = new Item
        {
            Id = IsEditMode ? _editingItemId : Guid.NewGuid(),
            Name = ItemName.Trim(),
            CategoryId = category.Id,
            Barcode = Barcode,
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

        IsSaving = false;
        await Shell.Current.GoToAsync("..");
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

    partial void OnNoExpiryChanged(bool value)
    {
        if (value)
            ExpiryDate = null;
        else
            ExpiryDate = DateTime.Today.AddDays(7);
    }

    private async Task LoadCategoriesAsync()
    {
        Categories.Clear();
        var categories = await _dataService.GetCategoriesAsync();
        foreach (var cat in categories.Where(c => c.IsActive).OrderBy(c => c.SortOrder))
            Categories.Add(cat);
    }
}
