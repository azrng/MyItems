using MyItems.ViewModels;

namespace MyItems.Views;

public partial class ItemLibraryPage : ContentPage
{
    private bool _isNavigatingToCategory;

    public ItemLibraryPage(ItemLibraryViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }

    private void OnSettingsClicked(object? sender, EventArgs e)
    {
        Drawer.ToggleDrawer();
    }

    private async void OnCategoryClicked(object? sender, TappedEventArgs e)
    {
        if (_isNavigatingToCategory)
            return;

        _isNavigatingToCategory = true;
        try
        {
            Drawer.IsOpen = false;
            await Shell.Current.GoToAsync("category");
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("打开失败", $"无法打开分类管理：{ex.Message}", "确定");
        }
        finally
        {
            _isNavigatingToCategory = false;
        }
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        if (BindingContext is ItemLibraryViewModel viewModel)
            viewModel.RefreshCommand.Execute(null);
    }
}
