using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Diagnostics;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ItemDetailViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;
    private bool _isOpeningEditor;

    [ObservableProperty]
    private ItemDisplayDto? item;

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string? errorMessage;

    public ItemDetailViewModel(IDataService dataService)
    {
        _dataService = dataService;
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.TryGetValue("itemId", out var idObj) && idObj is string idStr && Guid.TryParse(idStr, out var itemId))
        {
            _ = LoadItemAsync(itemId);
        }
    }

    public void RefreshCurrentItem()
    {
        if (!_isOpeningEditor && Item is not null)
            _ = LoadItemAsync(Item.ItemId);
    }

    [RelayCommand]
    private void Refresh()
    {
        if (Item is not null)
            _ = LoadItemAsync(Item.ItemId);
    }

    [RelayCommand(AllowConcurrentExecutions = true)]
    private async Task EditItemAsync()
    {
        if (Item is null) return;

        Debug.WriteLine($"[ItemDetail] EditItem itemId={Item.ItemId}, name={Item.ItemName}, categoryId={Item.CategoryId}");
        _isOpeningEditor = true;
        try
        {
            await Shell.Current.GoToAsync("add", new ShellNavigationQueryParameters
            {
                ["editDraft"] = Item
            });
        }
        finally
        {
            _isOpeningEditor = false;
        }
    }

    [RelayCommand]
    private async Task DeleteItemAsync()
    {
        if (Item is null) return;

        var confirm = await Shell.Current.DisplayAlertAsync("确认删除", $"确定要删除「{Item.ItemName}」吗？", "删除", "取消");
        if (!confirm) return;

        var result = await _dataService.DeleteItemAsync(Item.ItemId);
        if (result > 0)
            await Shell.Current.GoToAsync("..");
    }

    private async Task LoadItemAsync(Guid itemId)
    {
        IsLoading = true;
        ErrorMessage = null;

        try
        {
            Item = await _dataService.GetItemDisplayDtoByIdAsync(itemId);
            if (Item is null)
                ErrorMessage = "未找到该物品";
        }
        catch
        {
            ErrorMessage = "物品详情加载失败";
        }
        finally
        {
            IsLoading = false;
        }
    }
}
