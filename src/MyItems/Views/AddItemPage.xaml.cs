using MyItems.ViewModels;
using System.Diagnostics;

namespace MyItems.Views;

[QueryProperty(nameof(ItemIdQuery), "itemId")]
[QueryProperty(nameof(BarcodeQuery), "barcode")]
public partial class AddItemPage : ContentPage, IQueryAttributable
{
    private readonly AddItemViewModel _viewModel;
    public AddItemViewModel ViewModel => _viewModel;

    public AddItemPage(AddItemViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        BindingContext = viewModel;
        Shell.SetNavBarIsVisible(this, true);
        Shell.SetTabBarIsVisible(this, false);
        NavigationPage.SetHasNavigationBar(this, true);
        Loaded += OnLoaded;
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        Shell.SetNavBarIsVisible(this, true);
        Shell.SetTabBarIsVisible(this, false);
        NavigationPage.SetHasNavigationBar(this, true);

        await _viewModel.OnAppearingAsync();
        SynchronizeNativeControlsFromViewModel();
        LogLayoutMetrics("appearing");
    }

    private async void OnLoaded(object? sender, EventArgs e)
    {
        await _viewModel.ApplyDeferredUiHydrationAsync();
        SynchronizeNativeControlsFromViewModel();
        LogLayoutMetrics("loaded");
    }

    public string? ItemIdQuery
    {
        set => _viewModel.ApplyItemIdQuery(value);
    }

    public string? BarcodeQuery
    {
        set => _viewModel.ApplyBarcodeQuery(value);
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        _viewModel.ApplyQueryAttributes(query);
    }

    private async void OnSaveClicked(object? sender, EventArgs e)
    {
        ApplyNativeControlsToViewModel();
        if (_viewModel.SaveCommand.CanExecute(null))
            await _viewModel.SaveCommand.ExecuteAsync(null);
    }

    private void SynchronizeNativeControlsFromViewModel()
    {
        var snapshot = _viewModel.CurrentFormSnapshot;
        ItemNameEntry.Text = snapshot.ItemName;
        CategoryPicker.SelectedItem = snapshot.SelectedCategory;
        BrandEntry.Text = snapshot.Brand;
        LocationEntry.Text = snapshot.Location;
        QuantityLabel.Text = snapshot.Quantity.ToString();
        BarcodeEntry.Text = snapshot.Barcode;
        PurchaseDatePicker.Date = snapshot.PurchaseDate ?? DateTime.Today;
        PurchasePriceEntry.Text = snapshot.PurchasePrice?.ToString("0.##");
        ExpiryDatePicker.Date = snapshot.ExpiryDate ?? DateTime.Today;
        NoExpiryCheckBox.IsChecked = snapshot.NoExpiry;
        TrackDailyCostSwitch.IsToggled = snapshot.TrackDailyCost;
        NotesEditor.Text = snapshot.Notes;

        Debug.WriteLine($"[AddItemPage] Sync controls itemName={ItemNameEntry.Text}, category={(CategoryPicker.SelectedItem as Models.Category)?.Name ?? "null"}, quantity={QuantityLabel.Text}");
    }

    private void LogLayoutMetrics(string phase)
    {
        Debug.WriteLine($"[AddItemPage] Layout {phase}: page=({X:0.##},{Y:0.##},{Width:0.##},{Height:0.##}), content=({Content?.X:0.##},{Content?.Y:0.##},{Content?.Width:0.##},{Content?.Height:0.##})");
    }

    private void ApplyNativeControlsToViewModel()
    {
        _viewModel.ApplyFormSnapshot(new AddItemFormSnapshot(
            ItemNameEntry.Text ?? string.Empty,
            CategoryPicker.SelectedItem as Models.Category,
            BrandEntry.Text,
            LocationEntry.Text,
            TryParseQuantity(QuantityLabel.Text),
            BarcodeEntry.Text,
            PurchaseDatePicker.Date,
            TryParseNullableDecimal(PurchasePriceEntry.Text),
            NoExpiryCheckBox.IsChecked ? null : ExpiryDatePicker.Date,
            NoExpiryCheckBox.IsChecked,
            TrackDailyCostSwitch.IsToggled,
            NotesEditor.Text));
    }

    private static decimal? TryParseNullableDecimal(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        return decimal.TryParse(value.Trim(), out var parsed) ? parsed : null;
    }

    private static int TryParseQuantity(string? value)
    {
        return int.TryParse(value, out var parsed) ? parsed : 1;
    }
}
