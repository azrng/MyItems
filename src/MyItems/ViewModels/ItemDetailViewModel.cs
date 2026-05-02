using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MyItems.Models.DTOs;
using MyItems.Services;

namespace MyItems.ViewModels;

public partial class ItemDetailViewModel : ObservableObject, IQueryAttributable
{
    private readonly IDataService _dataService;

    public ObservableCollection<BatchDisplayDto> Batches { get; } = [];

    [ObservableProperty]
    private ItemDisplayDto? item;

    [ObservableProperty]
    private bool isLoading = true;

    [ObservableProperty]
    private string itemName = string.Empty;

    [ObservableProperty]
    private string categoryName = string.Empty;

    [ObservableProperty]
    private string? itemLocation;

    [ObservableProperty]
    private string? barcode;

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
    private async Task AddBatchAsync()
    {
        await Shell.Current.DisplayAlertAsync("添加批次", "添加批次功能将在后续版本实现", "确定");
    }

    [RelayCommand]
    private async Task DeleteBatchAsync(BatchDisplayDto batch)
    {
        var confirm = await Shell.Current.DisplayAlertAsync("确认移除", $"确定要移除批次「{batch.BatchLabel}」吗？此操作会从当前库存中删除该批次。", "移除", "取消");
        if (!confirm)
            return;

        var result = await _dataService.DeleteBatchAsync(batch.BatchId);
        if (result > 0)
            Batches.Remove(batch);
    }

    [RelayCommand]
    private async Task ConsumeBatchAsync(BatchDisplayDto batch)
    {
        var confirm = await Shell.Current.DisplayAlertAsync("确认已用完", $"确定将「{batch.ItemName}」的批次「{batch.BatchLabel}」标记为已用完吗？", "已用完", "取消");
        if (!confirm)
            return;

        var result = await _dataService.DeleteBatchAsync(batch.BatchId);
        if (result > 0)
            Batches.Remove(batch);
    }

    [RelayCommand]
    private async Task RemoveItemAsync()
    {
        if (Item is null)
            return;

        var confirm = await Shell.Current.DisplayAlertAsync("确认移除物品", $"确定要移除「{ItemName}」吗？该物品会从首页和物品库中隐藏。", "移除", "取消");
        if (!confirm)
            return;

        var result = await _dataService.ArchiveItemAsync(Item.ItemId);
        if (result > 0)
            await Shell.Current.GoToAsync("..");
    }

    private async Task LoadItemAsync(Guid itemId)
    {
        IsLoading = true;

        var items = await _dataService.GetItemDisplayDtosAsync();
        var item = items.FirstOrDefault(i => i.ItemId == itemId);
        if (item is null)
        {
            IsLoading = false;
            return;
        }

        Item = item;
        ItemName = item.Name;
        CategoryName = item.CategoryName;
        ItemLocation = item.DefaultLocation;
        Barcode = item.Barcode;

        var allBatches = await _dataService.GetBatchDisplayDtosAsync();
        var itemBatches = allBatches.Where(b => b.ItemId == itemId).ToList();

        Batches.Clear();
        foreach (var batch in itemBatches)
            Batches.Add(batch);

        IsLoading = false;
    }
}
