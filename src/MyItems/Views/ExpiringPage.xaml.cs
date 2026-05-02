using MyItems.ViewModels;

namespace MyItems.Views;

public partial class ExpiringPage : ContentPage
{
    public ExpiringPage(ExpiringViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        if (BindingContext is ExpiringViewModel viewModel)
            viewModel.RefreshCommand.Execute(null);
    }
}
