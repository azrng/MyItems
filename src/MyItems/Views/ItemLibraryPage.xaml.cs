using MyItems.Models;
using MyItems.ViewModels;

namespace MyItems.Views;

public partial class ItemLibraryPage : ContentPage
{
    public ItemLibraryPage(ItemLibraryViewModel viewModel)
    {
        InitializeComponent();
        BindingContext = viewModel;
    }

    private void OnCategoryClicked(object? sender, EventArgs e)
    {
        if (BindingContext is not ItemLibraryViewModel vm || sender is not Button btn)
            return;

        var category = btn.BindingContext as Category;
        vm.SelectedCategory = category;

        // Highlight selected chip
        var parent = btn.Parent as HorizontalStackLayout;
        if (parent is null) return;

        foreach (var child in parent.Children)
        {
            if (child is Button chip)
            {
                chip.BackgroundColor = chip == btn
                    ? Application.Current?.Resources.TryGetValue("AppPrimaryColor", out var c) == true ? (Color)c : Colors.Blue
                    : Application.Current?.Resources.TryGetValue("AppSurfaceColor", out var c2) == true ? (Color)c2 : Colors.LightGray;
                chip.TextColor = chip == btn
                    ? Colors.White
                    : Application.Current?.Resources.TryGetValue("AppTextColor", out var c3) == true ? (Color)c3 : Colors.Black;
            }
        }
    }
}
