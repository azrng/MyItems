using MyItems.Models;
using MyItems.Helpers;
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

    protected async override void OnNavigatedTo(NavigatedToEventArgs args)
    {
        base.OnNavigatedTo(args);

        // 检查是否有从高级搜索返回的过滤器
        if (BindingContext is ItemLibraryViewModel viewModel)
        {
            var searchFilter = SearchFilterHelper.GetFilter();
            if (searchFilter != null)
            {
                await viewModel.ApplySearchFilter(searchFilter);
            }
        }
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
