using MyItems.ViewModels;

namespace MyItems.Views;

public partial class ItemLibraryPage : ContentPage
{
    public ItemLibraryPage(ItemLibraryViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        if (BindingContext is ItemLibraryViewModel viewModel)
            viewModel.RefreshCommand.Execute(null);
    }
}
