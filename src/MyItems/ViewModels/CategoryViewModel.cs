using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class CategoryViewModel : ObservableObject
{
    public ObservableCollection<CategoryDto> Categories { get; } = [];

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string? newCategoryName;

    [ObservableProperty]
    private string? newCategoryIcon;

    [ObservableProperty]
    private bool isAdding;

    public CategoryViewModel()
    {
        LoadData();
    }

    [RelayCommand]
    private void Refresh()
    {
        IsLoading = true;
        LoadData();
        IsLoading = false;
    }

    [RelayCommand]
    private async Task AddCategoryAsync()
    {
        if (string.IsNullOrWhiteSpace(NewCategoryName))
            return;

        // Phase 2: persist to database
        IsAdding = true;
        await Task.Delay(300);

        Categories.Add(new CategoryDto
        {
            Id = Guid.NewGuid(),
            Name = NewCategoryName,
            Icon = string.IsNullOrWhiteSpace(NewCategoryIcon) ? "\U0001F3F7" : NewCategoryIcon,
            SortOrder = Categories.Count + 1,
            IsPreset = false,
            ItemCount = 0,
        });

        NewCategoryName = null;
        NewCategoryIcon = null;
        IsAdding = false;
    }

    [RelayCommand]
    private async Task DeleteCategoryAsync(CategoryDto category)
    {
        if (category.IsPreset)
        {
            await Shell.Current.DisplayAlert("提示", "预置分类不可删除", "确定");
            return;
        }

        if (category.ItemCount > 0)
        {
            await Shell.Current.DisplayAlert("提示", $"分类「{category.Name}」下有 {category.ItemCount} 个物品，无法删除", "确定");
            return;
        }

        var confirm = await Shell.Current.DisplayAlert("确认删除", $"确定要删除分类「{category.Name}」吗？", "删除", "取消");
        if (confirm)
        {
            Categories.Remove(category);
        }
    }

    private void LoadData()
    {
        Categories.Clear();
        foreach (var cat in MockDataService.GetCategoryDtos().OrderBy(c => c.SortOrder))
            Categories.Add(cat);
        IsLoading = false;
    }
}
