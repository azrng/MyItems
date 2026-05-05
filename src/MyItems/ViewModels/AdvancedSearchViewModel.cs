using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Helpers;
using MyItems.Models;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class AdvancedSearchViewModel : ObservableObject
{
    private readonly IDataService _dataService;

    [ObservableProperty]
    private SearchFilter filter = new();

    [ObservableProperty]
    private List<Category> categories = [];

    [ObservableProperty]
    private Category? selectedCategory;

    public AdvancedSearchViewModel(IDataService dataService)
    {
        _dataService = dataService;
        _ = InitializeAsync();
    }

    private async Task InitializeAsync()
    {
        Categories = await _dataService.GetCategoriesAsync();
        Categories.Insert(0, new Category { Id = Guid.Empty, Name = "全部分类" });
        SelectedCategory = Categories[0];
    }

    partial void OnSelectedCategoryChanged(Category? value)
    {
        Filter.CategoryId = value?.Id == Guid.Empty ? null : value?.Id;
    }

    [RelayCommand]
    private void Reset()
    {
        Filter.Clear();
        SelectedCategory = Categories[0];
    }

    [RelayCommand]
    private async Task SearchAsync()
    {
        // 通过辅助类传递搜索结果
        SearchFilterHelper.SetFilter(Filter);
        await Shell.Current.GoToAsync("..");
    }
}
