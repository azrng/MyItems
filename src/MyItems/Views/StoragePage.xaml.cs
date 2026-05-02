using MyItems.ViewModels;

namespace MyItems.Views;

public partial class StoragePage : ContentPage
{
    public StoragePage(StorageViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }
}
