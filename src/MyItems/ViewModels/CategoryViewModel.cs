using System.Collections.ObjectModel;
using System.ComponentModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Maui.Extensions;
using CommunityToolkit.Maui.Views;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models;
using MyItems.Models.DTOs;
using MyItems.Services;
using MyItems.Views;

namespace MyItems.ViewModels;

public partial class CategoryViewModel : ObservableObject
{
    private readonly IDataService _dataService;
    private bool _hasLoaded;

    public static readonly string[] CategoryIcons =
    [
        "📦", "🏷️", "📋", "🗂️",
        "🍎", "🍞", "🥛", "🍳",
        "💊", "🩹", "🏥",
        "📱", "💻", "🔌", "🔋",
        "👕", "👗", "🧣",
        "📚", "✏️", "📝", "🎨",
        "🏠", "🧴", "🧹", "💡", "🔑",
        "⚽", "🎮", "🧸",
        "🚗", "🚲",
        "⭐", "🌿", "🎁",
    ];

    public ObservableCollection<CategoryDto> Categories { get; } = [];
    public ObservableCollection<SelectableIcon> AvailableIcons { get; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string? newCategoryName;

    [ObservableProperty]
    private string? newCategoryIcon;

    [ObservableProperty]
    private bool isAdding;

    public CategoryViewModel(IDataService dataService)
    {
        _dataService = dataService;
        InitializeIcons();
    }

    private void InitializeIcons()
    {
        foreach (var icon in CategoryIcons)
            AvailableIcons.Add(new SelectableIcon(icon));

        if (AvailableIcons.Count > 0)
        {
            AvailableIcons[0].IsSelected = true;
            NewCategoryIcon = CategoryIcons[0];
        }
    }

    [RelayCommand]
    private async Task RefreshAsync()
    {
        IsLoading = true;
        await LoadDataAsync();
    }

    public async Task InitializeAsync()
    {
        if (_hasLoaded)
            return;

        IsLoading = true;
        await LoadDataAsync();
        _hasLoaded = true;
    }

    [RelayCommand]
    private async Task AddCategoryAsync()
    {
        if (string.IsNullOrWhiteSpace(NewCategoryName))
            return;

        IsAdding = true;

        var category = new Category
        {
            Id = Guid.NewGuid(),
            Name = NewCategoryName,
            Icon = NewCategoryIcon ?? CategoryIcons[0],
            SortOrder = Categories.Count + 1,
            IsPreset = false,
            IsActive = true,
        };

        await _dataService.SaveCategoryAsync(category);

        var dto = new CategoryDto
        {
            Id = category.Id,
            Name = category.Name,
            Icon = category.Icon,
            SortOrder = category.SortOrder,
            IsPreset = false,
            IsActive = true,
            ItemCount = 0,
        };
        dto.PropertyChanged += OnCategoryPropertyChanged;
        Categories.Add(dto);

        NewCategoryName = null;
        IsAdding = false;
    }

    [RelayCommand]
    private void SelectNewIcon(SelectableIcon icon)
    {
        foreach (var item in AvailableIcons)
            item.IsSelected = ReferenceEquals(item, icon);
        NewCategoryIcon = icon.Icon;
    }

    [RelayCommand]
    private async Task EditCategoryAsync(CategoryDto category)
    {
        var popup = new CategoryEditPopup(category.Name, category.Icon);
        var popupResult = await Shell.Current.ShowPopupAsync<CategoryEditResult>(popup, null, null);
        if (popupResult.WasDismissedByTappingOutsideOfPopup || popupResult.Result is null) return;

        var editResult = popupResult.Result;
        category.Name = editResult.Name;
        category.Icon = editResult.Icon;

        var cat = new Category
        {
            Id = category.Id,
            Name = editResult.Name,
            Icon = editResult.Icon,
            SortOrder = category.SortOrder,
            IsPreset = category.IsPreset,
            IsActive = category.IsActive,
        };
        await _dataService.SaveCategoryAsync(cat);
    }

    [RelayCommand]
    private async Task DeleteCategoryAsync(CategoryDto category)
    {
        if (category.IsPreset)
        {
            await Shell.Current.DisplayAlertAsync("提示", "预置分类不可删除", "确定");
            return;
        }

        if (category.ItemCount > 0)
        {
            await Shell.Current.DisplayAlertAsync("提示", $"分类「{category.Name}」下有 {category.ItemCount} 个物品，无法删除", "确定");
            return;
        }

        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除分类「{category.Name}」吗？", "删除", "取消");
        if (confirm)
        {
            var cat = new Category { Id = category.Id };
            await _dataService.DeleteCategoryAsync(cat);
            category.PropertyChanged -= OnCategoryPropertyChanged;
            Categories.Remove(category);
        }
    }

    [RelayCommand]
    private async Task SortUpAsync(CategoryDto category)
    {
        var index = Categories.IndexOf(category);
        if (index > 0)
        {
            var prev = Categories[index - 1];
            (category.SortOrder, prev.SortOrder) = (prev.SortOrder, category.SortOrder);
            ReorderCollection();
            await SaveSortOrderAsync(category);
            await SaveSortOrderAsync(prev);
        }
    }

    [RelayCommand]
    private async Task SortDownAsync(CategoryDto category)
    {
        var index = Categories.IndexOf(category);
        if (index < Categories.Count - 1)
        {
            var next = Categories[index + 1];
            (category.SortOrder, next.SortOrder) = (next.SortOrder, category.SortOrder);
            ReorderCollection();
            await SaveSortOrderAsync(category);
            await SaveSortOrderAsync(next);
        }
    }

    private void ReorderCollection()
    {
        var sorted = Categories.OrderBy(c => c.SortOrder).ToList();
        Categories.Clear();
        foreach (var cat in sorted)
            Categories.Add(cat);
    }

    private async Task SaveSortOrderAsync(CategoryDto dto)
    {
        var cat = new Category { Id = dto.Id, Name = dto.Name, Icon = dto.Icon, SortOrder = dto.SortOrder, IsPreset = dto.IsPreset, IsActive = dto.IsActive };
        await _dataService.SaveCategoryAsync(cat);
    }

    private async void OnCategoryPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(CategoryDto.IsActive) && sender is CategoryDto dto)
        {
            var cat = new Category { Id = dto.Id, Name = dto.Name, Icon = dto.Icon, SortOrder = dto.SortOrder, IsPreset = dto.IsPreset, IsActive = dto.IsActive };
            await _dataService.SaveCategoryAsync(cat);
        }
    }

    private async Task LoadDataAsync()
    {
        try
        {
            Categories.Clear();
            var dtos = await _dataService.GetCategoryDtosAsync();
            foreach (var cat in dtos.OrderBy(c => c.SortOrder))
            {
                cat.PropertyChanged += OnCategoryPropertyChanged;
                Categories.Add(cat);
            }
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("加载失败", $"无法加载分类：{ex.Message}", "确定");
        }
        finally
        {
            IsLoading = false;
        }
    }
}

public partial class SelectableIcon : ObservableObject
{
    public string Icon { get; }

    [ObservableProperty]
    private bool isSelected;

    public SelectableIcon(string icon, bool isSelected = false)
    {
        Icon = icon;
        IsSelected = isSelected;
    }
}
