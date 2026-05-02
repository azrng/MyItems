using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ItemDetailViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;

    [ObservableProperty]
    private ItemDisplayDto? item;

    [ObservableProperty]
    private bool isLoading = true;

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
        await Shell.Current.GoToAsync($"add?itemId={Item.ItemId}");
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

        var items = await _dataService.GetItemDisplayDtosAsync();
        Item = items.FirstOrDefault(i => i.ItemId == itemId);

        IsLoading = false;
    }
}
