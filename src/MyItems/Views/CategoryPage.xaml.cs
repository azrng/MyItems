using MyItems.ViewModels;

namespace MyItems.Views;

public partial class CategoryPage : ContentPage
{
    private readonly CategoryViewModel _viewModel;

    public CategoryPage(CategoryViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        BindingContext = _viewModel;
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        try
        {
            await Task.Yield();
            await _viewModel.InitializeAsync();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"CategoryPage.OnAppearing error: {ex}");
        }
    }
}
