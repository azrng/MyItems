using System.Windows.Input;
using MyItems.Views;

namespace MyItems;

public partial class AppShell : Shell
{
    public ICommand AboutCommand { get; }

    public AppShell()
    {
        InitializeComponent();

        AboutCommand = new Command(async () =>
        {
            await GoToAsync(nameof(AboutPage));
        });

        Routing.RegisterRoute(nameof(ItemDetailPage), typeof(ItemDetailPage));
        Routing.RegisterRoute(nameof(AboutPage), typeof(AboutPage));
    }
}
