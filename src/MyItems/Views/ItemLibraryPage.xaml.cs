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

    private void OnDeleteItemSwipe(object? sender, EventArgs e)
    {
        if (sender is SwipeItem { CommandParameter: Guid itemId } &&
            BindingContext is ItemLibraryViewModel viewModel)
        {
            viewModel.DeleteItemCommand.Execute(itemId);
        }
    }
}
