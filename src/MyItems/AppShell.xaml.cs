using MyItems.ViewModels;
using MyItems.Views;

namespace MyItems;

public partial class AppShell : Shell
{
    public AppShell()
    {
        InitializeComponent();

        Routing.RegisterRoute(nameof(ItemDetailPage), typeof(ItemDetailPage));
    }
}
