using System.Windows.Input;
using MyItems.Views;

namespace MyItems;

public partial class AppShell : Shell
{
    public ICommand AboutCommand { get; }
    public ICommand CategoryCommand { get; }

    public AppShell()
    {
        InitializeComponent();

        AboutCommand = new Command(async () =>
        {
            await GoToAsync(nameof(AboutPage));
        });

        CategoryCommand = new Command(async () =>
        {
            await GoToAsync("category");
        });

        Routing.RegisterRoute("add", typeof(AddItemPage));
        Routing.RegisterRoute("itemdetail", typeof(ItemDetailPage));
        Routing.RegisterRoute(nameof(AboutPage), typeof(AboutPage));
        Routing.RegisterRoute("category", typeof(CategoryPage));
    }
}
