using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class AddItemViewModel : ObservableObject
{
    private readonly IDataService _dataService;

    public ObservableCollection<Category> Categories { get; } = [];

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
        _ = LoadCategoriesAsync();
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
            BatchLabel = DateTime.Now.ToString("yyyy-MM-dd HH:mm"),
            CreatedAt = DateTime.Now,
        };

        await _dataService.SaveBatchAsync(batch);

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
