using MyItems.ViewModels;

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
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        ApplyRouteFallbackParameters();
        await _viewModel.OnAppearingAsync();
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

    private void ApplyRouteFallbackParameters()
    {
        var location = Shell.Current?.CurrentState?.Location;
        if (location is null)
            return;

        var locationText = location.IsAbsoluteUri
            ? location.Query
            : location.OriginalString;

        var queryIndex = locationText.IndexOf('?', StringComparison.Ordinal);
        if (queryIndex < 0 || queryIndex >= locationText.Length - 1)
            return;

        var query = locationText[(queryIndex + 1)..];
        if (string.IsNullOrWhiteSpace(query))
            return;

        foreach (var segment in query.Split('&', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var parts = segment.Split('=', 2);
            if (parts.Length != 2)
                continue;

            var key = Uri.UnescapeDataString(parts[0]);
            var value = Uri.UnescapeDataString(parts[1]);

            if (string.Equals(key, "itemId", StringComparison.OrdinalIgnoreCase))
                _viewModel.ApplyItemIdQuery(value);
            else if (string.Equals(key, "barcode", StringComparison.OrdinalIgnoreCase))
                _viewModel.ApplyBarcodeQuery(value);
        }
    }
}
