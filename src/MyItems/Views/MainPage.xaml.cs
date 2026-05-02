using MyItems.ViewModels;

namespace MyItems.Views;

public partial class MainPage : ContentPage
{
    public MainPage(MainViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        if (BindingContext is MainViewModel viewModel)
            viewModel.RefreshCommand.Execute(null);
    }

    private async void OnDeleteItemSwipe(object? sender, EventArgs e)
    {
        if (sender is SwipeItem { CommandParameter: Guid itemId } &&
            BindingContext is MainViewModel viewModel)
        {
            var confirm = await Shell.Current.DisplayAlertAsync("确认删除", "确定要删除这个物品吗？", "删除", "取消");
            if (confirm)
            {
                await viewModel.DeleteItemByIdAsync(itemId);
            }
        }
    }
}
