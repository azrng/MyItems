using MyItems.ViewModels;
using MyItems.Models.DTOs;

namespace MyItems.Views;

public partial class CategoryPage : ContentPage
{
    private readonly CategoryViewModel _viewModel;

    public CategoryPage(CategoryViewModel viewModel)
    {
        _viewModel = viewModel;

        try
        {
            InitializeComponent();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"CategoryPage.InitializeComponent error: {ex}");
            Content = CreateLoadFailedView(ex.Message);
        }

        BindingContext = _viewModel;
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        try
        {
            await Task.Yield();
            await _viewModel.InitializeAsync();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"CategoryPage.OnAppearing error: {ex}");
        }
    }

    private void OnDeleteCategoryClicked(object? sender, EventArgs e)
    {
        if (sender is BindableObject { BindingContext: CategoryDto category })
            _viewModel.DeleteCategoryCommand.Execute(category);
    }

    private void OnSortUpClicked(object? sender, EventArgs e)
    {
        if (sender is BindableObject { BindingContext: CategoryDto category })
            _viewModel.SortUpCommand.Execute(category);
    }

    private void OnSortDownClicked(object? sender, EventArgs e)
    {
        if (sender is BindableObject { BindingContext: CategoryDto category })
            _viewModel.SortDownCommand.Execute(category);
    }

    private static View CreateLoadFailedView(string message)
    {
        return new ScrollView
        {
            Content = new VerticalStackLayout
            {
                Padding = 16,
                Spacing = 12,
                Children =
                {
                    new Label
                    {
                        Text = "分类管理加载失败",
                        FontSize = 20,
                        FontAttributes = FontAttributes.Bold,
                    },
                    new Label
                    {
                        Text = message,
                        FontSize = 14,
                    },
                },
            },
        };
    }
}
