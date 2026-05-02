using CommunityToolkit.Maui.Views;
using Microsoft.Maui.Controls.Shapes;
using MyItems.ViewModels;

namespace MyItems.Views;

public class CategoryEditPopup : Popup<CategoryEditResult>
{
    private readonly Entry _nameEntry;
    private string? _selectedIcon;
    private readonly List<Button> _iconButtons = [];
    private const int Columns = 7;

    public CategoryEditPopup(string name, string? icon)
    {
        _selectedIcon = icon ?? CategoryViewModel.CategoryIcons[0];

        var cardBg = GetColor("AppCardBackgroundColor");
        var borderClr = GetColor("AppBorderColor");
        var textClr = GetColor("AppTextColor");
        var primaryClr = GetColor("AppPrimaryColor");
        var surfaceClr = GetColor("AppSurfaceColor");

        _nameEntry = new Entry
        {
            Text = name,
            Placeholder = "分类名称",
            HeightRequest = 44,
            FontSize = 14,
            TextColor = textClr,
        };

        var iconGrid = BuildIconGrid(primaryClr, surfaceClr, textClr);
        var buttonGrid = BuildButtonGrid(surfaceClr, textClr, primaryClr);

        var layout = new VerticalStackLayout
        {
            Spacing = 16,
            Children =
            {
                new Label
                {
                    Text = "编辑分类",
                    FontSize = 18,
                    FontAttributes = FontAttributes.Bold,
                    TextColor = textClr,
                },
                _nameEntry,
                new Label
                {
                    Text = "选择图标",
                    FontSize = 16,
                    TextColor = textClr,
                },
                iconGrid,
                buttonGrid,
            },
        };

        Content = new Border
        {
            BackgroundColor = cardBg,
            StrokeShape = new RoundRectangle { CornerRadius = new CornerRadius(16) },
            Stroke = new SolidColorBrush(borderClr),
            Padding = new Thickness(20),
            WidthRequest = 340,
            Content = layout,
        };
    }

    private Grid BuildIconGrid(Color primaryClr, Color surfaceClr, Color textClr)
    {
        var icons = CategoryViewModel.CategoryIcons;
        var rows = (icons.Length + Columns - 1) / Columns;
        var colDefs = new ColumnDefinitionCollection();
        var rowDefs = new RowDefinitionCollection();
        for (var i = 0; i < Columns; i++)
            colDefs.Add(new ColumnDefinition(GridLength.Auto));
        for (var i = 0; i < rows; i++)
            rowDefs.Add(new RowDefinition(GridLength.Auto));

        var grid = new Grid
        {
            ColumnDefinitions = colDefs,
            RowDefinitions = rowDefs,
            RowSpacing = 4,
            ColumnSpacing = 4,
            HorizontalOptions = LayoutOptions.Center,
        };

        for (var i = 0; i < icons.Length; i++)
        {
            var iconStr = icons[i];
            var isSelected = iconStr == _selectedIcon;
            var btn = new Button
            {
                Text = iconStr,
                WidthRequest = 40,
                HeightRequest = 40,
                FontSize = 20,
                CornerRadius = 8,
                Padding = 0,
                BackgroundColor = isSelected ? primaryClr : surfaceClr,
                TextColor = isSelected ? Colors.White : textClr,
            };
            btn.Clicked += (_, _) =>
            {
                _selectedIcon = iconStr;
                UpdateIconSelection(primaryClr, surfaceClr, textClr);
            };
            _iconButtons.Add(btn);
            grid.Add(btn, i % Columns, i / Columns);
        }

        return grid;
    }

    private Grid BuildButtonGrid(Color surfaceClr, Color textClr, Color primaryClr)
    {
        var cancelBtn = new Button
        {
            Text = "取消",
            BackgroundColor = surfaceClr,
            TextColor = textClr,
            FontSize = 16,
            HeightRequest = 44,
            CornerRadius = 10,
        };
        cancelBtn.Clicked += async (_, _) => await CloseAsync(null);
        Grid.SetColumn(cancelBtn, 0);

        var saveBtn = new Button
        {
            Text = "保存",
            BackgroundColor = primaryClr,
            TextColor = Colors.White,
            FontSize = 16,
            FontAttributes = FontAttributes.Bold,
            HeightRequest = 44,
            CornerRadius = 10,
        };
        saveBtn.Clicked += OnSaveClicked;
        Grid.SetColumn(saveBtn, 1);

        var grid = new Grid
        {
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star),
            },
            ColumnSpacing = 12,
        };
        grid.Children.Add(cancelBtn);
        grid.Children.Add(saveBtn);
        return grid;
    }

    private void UpdateIconSelection(Color primaryClr, Color surfaceClr, Color textClr)
    {
        foreach (var btn in _iconButtons)
        {
            var isSelected = btn.Text == _selectedIcon;
            btn.BackgroundColor = isSelected ? primaryClr : surfaceClr;
            btn.TextColor = isSelected ? Colors.White : textClr;
        }
    }

    private async void OnSaveClicked(object? sender, EventArgs e)
    {
        var name = _nameEntry.Text?.Trim();
        if (string.IsNullOrWhiteSpace(name)) return;
        await CloseAsync(new CategoryEditResult(name, _selectedIcon));
    }

    private static Color GetColor(string key) =>
        (Color)Application.Current.Resources[key];
}

public record CategoryEditResult(string Name, string? Icon);
