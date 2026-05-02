using MyItems.ViewModels;

namespace MyItems.Views;

public partial class AddItemPage : ContentPage
{
    public AddItemPage(AddItemViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }
}
