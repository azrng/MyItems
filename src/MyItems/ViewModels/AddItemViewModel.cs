using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class AddItemViewModel : ObservableObject
{
    public ObservableCollection<Category> Categories { get; } = [];

    [ObservableProperty]
    private string itemName = string.Empty;

    [ObservableProperty]
    private Category? selectedCategory;

    [ObservableProperty]
    private string? barcode;

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
    private DateTime? warrantyDate;

    [ObservableProperty]
    private bool showWarrantyField;

    [ObservableProperty]
    private int quantity = 1;

    [ObservableProperty]
    private string? notes;

    [ObservableProperty]
    private bool isSaving;

    [ObservableProperty]
    private string? errorMessage;

    public AddItemViewModel()
    {
        LoadCategories();
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

        // Phase 1: mock save — Phase 2 will implement real persistence
        await Task.Delay(500);

        var dto = new AddItemDto
        {
            Name = ItemName,
            CategoryId = SelectedCategory.Id,
            Barcode = Barcode,
            DefaultLocation = Location,
            PurchaseDate = PurchaseDate,
            PurchasePrice = PurchasePrice,
            ExpiryDate = NoExpiry ? null : ExpiryDate,
            NoExpiry = NoExpiry,
            WarrantyDate = ShowWarrantyField ? WarrantyDate : null,
            Location = Location,
            Quantity = Quantity,
            Notes = Notes,
        };

        IsSaving = false;

        await Shell.Current.GoToAsync("..");
    }

    [RelayCommand]
    private async Task ScanBarcodeAsync()
    {
        // Phase 2: implement ZXing barcode scanning
        await Shell.Current.DisplayAlert("扫码", "扫码功能将在后续版本实现", "确定");
    }

    partial void OnSelectedCategoryChanged(Category? value)
    {
        ShowWarrantyField = value?.Name == "电子产品";
    }

    partial void OnNoExpiryChanged(bool value)
    {
        if (value)
            ExpiryDate = null;
        else
            ExpiryDate = DateTime.Today.AddMonths(1);
    }

    private void LoadCategories()
    {
        Categories.Clear();
        foreach (var cat in MockDataService.GetPresetCategories().OrderBy(c => c.SortOrder))
            Categories.Add(cat);
    }
}
