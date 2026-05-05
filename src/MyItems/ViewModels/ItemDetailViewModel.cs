using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.DependencyInjection;
using System.Diagnostics;
using MyItems.Models.DTOs;
using MyItems.Services;
using MyItems.Views;

namespace MyItems.ViewModels;

public partial class ItemDetailViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;
    private readonly IServiceProvider _serviceProvider;

    [ObservableProperty]
    private ItemDisplayDto? item;

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string? errorMessage;

    public ItemDetailViewModel(IDataService dataService, IServiceProvider serviceProvider)
    {
        _dataService = dataService;
        _serviceProvider = serviceProvider;
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.TryGetValue("itemId", out var idObj) && idObj is string idStr && Guid.TryParse(idStr, out var itemId))
        {
            _ = LoadItemAsync(itemId);
        }
    }

    [RelayCommand]
    private void Refresh()
    {
        if (Item is not null)
            _ = LoadItemAsync(Item.ItemId);
    }

    [RelayCommand]
    private async Task EditItemAsync()
    {
        if (Item is null) return;

        Debug.WriteLine($"[ItemDetail] EditItem itemId={Item.ItemId}, name={Item.ItemName}, categoryId={Item.CategoryId}");
        var page = _serviceProvider.GetRequiredService<AddItemPage>();
        page.ViewModel.PrepareForEdit(Item);
        await Shell.Current.Navigation.PushAsync(page);
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
